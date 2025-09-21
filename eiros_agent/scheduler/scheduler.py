
"""
Task Scheduler - manages task execution and scheduling
"""
import asyncio
from typing import Dict, Any, Optional, List, Callable, Union
from datetime import datetime, timedelta
import uuid
import json
from pathlib import Path
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from apscheduler.triggers.date import DateTrigger
from apscheduler.triggers.interval import IntervalTrigger
from loguru import logger

from ..core.exceptions import SchedulerError, TaskExecutionError
from .task_manager import TaskManager
from .macro_engine import MacroEngine
from .triggers import TimeTrigger, EventTrigger, ConditionTrigger


class TaskScheduler:
    """
    Advanced task scheduler with macro support
    """
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize task scheduler"""
        self.config = config
        self.scheduler = AsyncIOScheduler()
        self.task_manager = TaskManager(config)
        self.macro_engine = MacroEngine()
        
        # Configuration
        self.max_concurrent_tasks = config.get("max_concurrent_tasks", 10)
        self.task_timeout = config.get("task_timeout", 300)
        self.retry_attempts = config.get("retry_attempts", 3)
        self.retry_delay = config.get("retry_delay", 5)
        
        # Storage
        self.storage_config = config.get("storage", {})
        self.storage_path = Path(self.storage_config.get("path", "./data/tasks"))
        self.storage_path.mkdir(parents=True, exist_ok=True)
        
        # Runtime state
        self.running_tasks: Dict[str, asyncio.Task] = {}
        self.task_semaphore = asyncio.Semaphore(self.max_concurrent_tasks)
        self.is_initialized = False
        
        logger.info("TaskScheduler initialized")
    
    async def initialize(self) -> None:
        """Initialize task scheduler"""
        try:
            logger.info("Initializing task scheduler...")
            
            # Initialize components
            await self.task_manager.initialize()
            await self.macro_engine.initialize()
            
            # Start scheduler
            self.scheduler.start()
            
            # Load persisted tasks
            await self._load_persisted_tasks()
            
            self.is_initialized = True
            logger.info("Task scheduler initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize task scheduler: {e}")
            raise SchedulerError(f"Scheduler initialization failed: {e}")
    
    async def shutdown(self) -> None:
        """Shutdown task scheduler"""
        logger.info("Shutting down task scheduler...")
        
        try:
            # Cancel running tasks
            for task_id, task in self.running_tasks.items():
                if not task.done():
                    task.cancel()
                    logger.info(f"Cancelled task: {task_id}")
            
            # Wait for tasks to complete
            if self.running_tasks:
                await asyncio.gather(*self.running_tasks.values(), return_exceptions=True)
            
            # Shutdown scheduler
            self.scheduler.shutdown()
            
            # Shutdown components
            await self.task_manager.shutdown()
            await self.macro_engine.shutdown()
            
            self.is_initialized = False
            logger.info("Task scheduler shutdown complete")
            
        except Exception as e:
            logger.error(f"Error during scheduler shutdown: {e}")
    
    async def schedule_task(self, task_config: Dict[str, Any]) -> str:
        """Schedule a task for execution"""
        if not self.is_initialized:
            raise SchedulerError("Scheduler not initialized")
        
        try:
            task_id = task_config.get("id", str(uuid.uuid4()))
            task_name = task_config.get("name", f"task_{task_id}")
            
            logger.info(f"Scheduling task: {task_name} ({task_id})")
            
            # Parse trigger configuration
            trigger_config = task_config.get("trigger", {})
            trigger = await self._create_trigger(trigger_config)
            
            # Schedule with APScheduler
            job = self.scheduler.add_job(
                self._execute_task_wrapper,
                trigger=trigger,
                args=[task_config],
                id=task_id,
                name=task_name,
                max_instances=1,
                coalesce=True,
                misfire_grace_time=30
            )
            
            # Persist task configuration
            await self._persist_task(task_config)
            
            logger.info(f"Task scheduled successfully: {task_name}")
            return task_id
            
        except Exception as e:
            logger.error(f"Failed to schedule task: {e}")
            raise SchedulerError(f"Task scheduling failed: {e}")
    
    async def execute_task_now(self, task_config: Dict[str, Any]) -> Dict[str, Any]:
        """Execute a task immediately"""
        if not self.is_initialized:
            raise SchedulerError("Scheduler not initialized")
        
        task_id = task_config.get("id", str(uuid.uuid4()))
        task_name = task_config.get("name", f"task_{task_id}")
        
        logger.info(f"Executing task immediately: {task_name}")
        
        try:
            result = await self._execute_task(task_config)
            logger.info(f"Task executed successfully: {task_name}")
            return result
            
        except Exception as e:
            logger.error(f"Task execution failed: {e}")
            raise TaskExecutionError(f"Task execution failed: {e}")
    
    async def execute_macro(self, macro_config: Dict[str, Any], variables: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Execute a macro"""
        if not self.is_initialized:
            raise SchedulerError("Scheduler not initialized")
        
        macro_name = macro_config.get("name", "unnamed_macro")
        logger.info(f"Executing macro: {macro_name}")
        
        try:
            result = await self.macro_engine.execute_macro(macro_config, variables or {})
            logger.info(f"Macro executed successfully: {macro_name}")
            return result
            
        except Exception as e:
            logger.error(f"Macro execution failed: {e}")
            raise TaskExecutionError(f"Macro execution failed: {e}")
    
    async def cancel_task(self, task_id: str) -> bool:
        """Cancel a scheduled task"""
        try:
            # Cancel scheduled job
            try:
                self.scheduler.remove_job(task_id)
                logger.info(f"Cancelled scheduled task: {task_id}")
            except Exception:
                pass  # Job might not exist
            
            # Cancel running task
            if task_id in self.running_tasks:
                task = self.running_tasks[task_id]
                if not task.done():
                    task.cancel()
                    logger.info(f"Cancelled running task: {task_id}")
                del self.running_tasks[task_id]
            
            # Remove persisted task
            await self._remove_persisted_task(task_id)
            
            return True
            
        except Exception as e:
            logger.error(f"Failed to cancel task {task_id}: {e}")
            return False
    
    async def get_task_status(self, task_id: str) -> Optional[Dict[str, Any]]:
        """Get status of a task"""
        try:
            # Check if task is scheduled
            job = self.scheduler.get_job(task_id)
            if job:
                return {
                    "id": task_id,
                    "name": job.name,
                    "status": "scheduled",
                    "next_run": job.next_run_time.isoformat() if job.next_run_time else None,
                    "trigger": str(job.trigger)
                }
            
            # Check if task is running
            if task_id in self.running_tasks:
                task = self.running_tasks[task_id]
                return {
                    "id": task_id,
                    "status": "running" if not task.done() else "completed",
                    "done": task.done()
                }
            
            return None
            
        except Exception as e:
            logger.error(f"Failed to get task status: {e}")
            return None
    
    async def list_tasks(self) -> List[Dict[str, Any]]:
        """List all tasks"""
        tasks = []
        
        # Scheduled tasks
        for job in self.scheduler.get_jobs():
            tasks.append({
                "id": job.id,
                "name": job.name,
                "status": "scheduled",
                "next_run": job.next_run_time.isoformat() if job.next_run_time else None,
                "trigger": str(job.trigger)
            })
        
        # Running tasks
        for task_id, task in self.running_tasks.items():
            tasks.append({
                "id": task_id,
                "status": "running" if not task.done() else "completed",
                "done": task.done()
            })
        
        return tasks
    
    async def _execute_task_wrapper(self, task_config: Dict[str, Any]) -> None:
        """Wrapper for task execution with concurrency control"""
        task_id = task_config.get("id", str(uuid.uuid4()))
        
        async with self.task_semaphore:
            try:
                # Create task
                task = asyncio.create_task(self._execute_task(task_config))
                self.running_tasks[task_id] = task
                
                # Execute with timeout
                await asyncio.wait_for(task, timeout=self.task_timeout)
                
            except asyncio.TimeoutError:
                logger.error(f"Task {task_id} timed out")
                if task_id in self.running_tasks:
                    self.running_tasks[task_id].cancel()
            except Exception as e:
                logger.error(f"Task {task_id} failed: {e}")
            finally:
                # Cleanup
                if task_id in self.running_tasks:
                    del self.running_tasks[task_id]
    
    async def _execute_task(self, task_config: Dict[str, Any]) -> Dict[str, Any]:
        """Execute a single task"""
        task_type = task_config.get("type", "macro")
        
        if task_type == "macro":
            return await self.macro_engine.execute_macro(
                task_config.get("macro", {}),
                task_config.get("variables", {})
            )
        else:
            return await self.task_manager.execute_task(task_config)
    
    async def _create_trigger(self, trigger_config: Dict[str, Any]):
        """Create APScheduler trigger from configuration"""
        trigger_type = trigger_config.get("type", "date")
        
        if trigger_type == "cron":
            # Cron trigger
            cron_expr = trigger_config.get("cron", "0 * * * *")
            return CronTrigger.from_crontab(cron_expr)
            
        elif trigger_type == "interval":
            # Interval trigger
            seconds = trigger_config.get("seconds", 0)
            minutes = trigger_config.get("minutes", 0)
            hours = trigger_config.get("hours", 0)
            days = trigger_config.get("days", 0)
            
            return IntervalTrigger(
                seconds=seconds,
                minutes=minutes,
                hours=hours,
                days=days
            )
            
        elif trigger_type == "date":
            # Date trigger
            run_date = trigger_config.get("run_date")
            if isinstance(run_date, str):
                run_date = datetime.fromisoformat(run_date)
            elif run_date is None:
                run_date = datetime.now()
            
            return DateTrigger(run_date=run_date)
            
        else:
            raise SchedulerError(f"Unknown trigger type: {trigger_type}")
    
    async def _persist_task(self, task_config: Dict[str, Any]) -> None:
        """Persist task configuration"""
        try:
            task_id = task_config.get("id")
            if not task_id:
                return
            
            task_file = self.storage_path / f"{task_id}.json"
            with open(task_file, 'w', encoding='utf-8') as f:
                json.dump(task_config, f, indent=2, default=str)
                
        except Exception as e:
            logger.error(f"Failed to persist task: {e}")
    
    async def _remove_persisted_task(self, task_id: str) -> None:
        """Remove persisted task"""
        try:
            task_file = self.storage_path / f"{task_id}.json"
            if task_file.exists():
                task_file.unlink()
                
        except Exception as e:
            logger.error(f"Failed to remove persisted task: {e}")
    
    async def _load_persisted_tasks(self) -> None:
        """Load persisted tasks on startup"""
        try:
            for task_file in self.storage_path.glob("*.json"):
                try:
                    with open(task_file, 'r', encoding='utf-8') as f:
                        task_config = json.load(f)
                    
                    # Only reschedule if task has recurring trigger
                    trigger_config = task_config.get("trigger", {})
                    if trigger_config.get("type") in ["cron", "interval"]:
                        await self.schedule_task(task_config)
                        logger.info(f"Restored task: {task_config.get('name')}")
                        
                except Exception as e:
                    logger.error(f"Failed to load task from {task_file}: {e}")
                    
        except Exception as e:
            logger.error(f"Failed to load persisted tasks: {e}")
    
    def get_status(self) -> Dict[str, Any]:
        """Get scheduler status"""
        return {
            "initialized": self.is_initialized,
            "running": self.scheduler.running,
            "scheduled_jobs": len(self.scheduler.get_jobs()),
            "running_tasks": len(self.running_tasks),
            "max_concurrent_tasks": self.max_concurrent_tasks,
            "task_timeout": self.task_timeout
        }
