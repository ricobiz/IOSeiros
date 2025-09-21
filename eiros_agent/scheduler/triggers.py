
"""
Trigger system for task scheduling
"""
import asyncio
from typing import Dict, Any, Optional, Callable, List
from datetime import datetime, timedelta
from abc import ABC, abstractmethod
from loguru import logger


class BaseTrigger(ABC):
    """Base class for all triggers"""
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize trigger"""
        self.config = config
        self.is_active = False
        self.callbacks: List[Callable] = []
    
    @abstractmethod
    async def start(self) -> None:
        """Start the trigger"""
        pass
    
    @abstractmethod
    async def stop(self) -> None:
        """Stop the trigger"""
        pass
    
    def add_callback(self, callback: Callable) -> None:
        """Add callback to be called when trigger fires"""
        self.callbacks.append(callback)
    
    def remove_callback(self, callback: Callable) -> None:
        """Remove callback"""
        if callback in self.callbacks:
            self.callbacks.remove(callback)
    
    async def fire(self, context: Optional[Dict[str, Any]] = None) -> None:
        """Fire the trigger and call all callbacks"""
        context = context or {}
        
        for callback in self.callbacks:
            try:
                if asyncio.iscoroutinefunction(callback):
                    await callback(context)
                else:
                    callback(context)
            except Exception as e:
                logger.error(f"Trigger callback failed: {e}")


class TimeTrigger(BaseTrigger):
    """Time-based trigger"""
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize time trigger"""
        super().__init__(config)
        
        self.trigger_type = config.get("type", "once")  # once, interval, cron
        self.interval = config.get("interval", 60)  # seconds
        self.cron_expression = config.get("cron")
        self.start_time = config.get("start_time")
        self.end_time = config.get("end_time")
        
        self._task: Optional[asyncio.Task] = None
        
        logger.info(f"TimeTrigger initialized: {self.trigger_type}")
    
    async def start(self) -> None:
        """Start the time trigger"""
        if self.is_active:
            return
        
        self.is_active = True
        
        if self.trigger_type == "once":
            self._task = asyncio.create_task(self._run_once())
        elif self.trigger_type == "interval":
            self._task = asyncio.create_task(self._run_interval())
        elif self.trigger_type == "cron":
            self._task = asyncio.create_task(self._run_cron())
        
        logger.info(f"TimeTrigger started: {self.trigger_type}")
    
    async def stop(self) -> None:
        """Stop the time trigger"""
        if not self.is_active:
            return
        
        self.is_active = False
        
        if self._task and not self._task.done():
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        
        logger.info(f"TimeTrigger stopped: {self.trigger_type}")
    
    async def _run_once(self) -> None:
        """Run trigger once at specified time"""
        try:
            if self.start_time:
                if isinstance(self.start_time, str):
                    start_time = datetime.fromisoformat(self.start_time)
                else:
                    start_time = self.start_time
                
                now = datetime.now()
                if start_time > now:
                    delay = (start_time - now).total_seconds()
                    await asyncio.sleep(delay)
            
            if self.is_active:
                await self.fire({"trigger_time": datetime.now()})
                
        except asyncio.CancelledError:
            pass
        except Exception as e:
            logger.error(f"TimeTrigger once execution failed: {e}")
    
    async def _run_interval(self) -> None:
        """Run trigger at regular intervals"""
        try:
            # Wait for start time if specified
            if self.start_time:
                if isinstance(self.start_time, str):
                    start_time = datetime.fromisoformat(self.start_time)
                else:
                    start_time = self.start_time
                
                now = datetime.now()
                if start_time > now:
                    delay = (start_time - now).total_seconds()
                    await asyncio.sleep(delay)
            
            while self.is_active:
                # Check end time
                if self.end_time:
                    if isinstance(self.end_time, str):
                        end_time = datetime.fromisoformat(self.end_time)
                    else:
                        end_time = self.end_time
                    
                    if datetime.now() >= end_time:
                        break
                
                await self.fire({"trigger_time": datetime.now()})
                await asyncio.sleep(self.interval)
                
        except asyncio.CancelledError:
            pass
        except Exception as e:
            logger.error(f"TimeTrigger interval execution failed: {e}")
    
    async def _run_cron(self) -> None:
        """Run trigger based on cron expression"""
        try:
            from croniter import croniter
            
            if not self.cron_expression:
                raise ValueError("Cron expression is required for cron trigger")
            
            cron = croniter(self.cron_expression, datetime.now())
            
            while self.is_active:
                next_run = cron.get_next(datetime)
                now = datetime.now()
                
                # Check end time
                if self.end_time:
                    if isinstance(self.end_time, str):
                        end_time = datetime.fromisoformat(self.end_time)
                    else:
                        end_time = self.end_time
                    
                    if next_run >= end_time:
                        break
                
                # Wait until next run time
                delay = (next_run - now).total_seconds()
                if delay > 0:
                    await asyncio.sleep(delay)
                
                if self.is_active:
                    await self.fire({"trigger_time": datetime.now()})
                
        except ImportError:
            logger.error("croniter package required for cron triggers. Install with: pip install croniter")
        except asyncio.CancelledError:
            pass
        except Exception as e:
            logger.error(f"TimeTrigger cron execution failed: {e}")


class EventTrigger(BaseTrigger):
    """Event-based trigger"""
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize event trigger"""
        super().__init__(config)
        
        self.event_name = config.get("event_name", "default_event")
        self.event_filter = config.get("event_filter", {})
        self.max_triggers = config.get("max_triggers", 0)  # 0 = unlimited
        
        self._trigger_count = 0
        self._event_queue = asyncio.Queue()
        self._task: Optional[asyncio.Task] = None
        
        logger.info(f"EventTrigger initialized: {self.event_name}")
    
    async def start(self) -> None:
        """Start the event trigger"""
        if self.is_active:
            return
        
        self.is_active = True
        self._task = asyncio.create_task(self._process_events())
        
        logger.info(f"EventTrigger started: {self.event_name}")
    
    async def stop(self) -> None:
        """Stop the event trigger"""
        if not self.is_active:
            return
        
        self.is_active = False
        
        if self._task and not self._task.done():
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        
        logger.info(f"EventTrigger stopped: {self.event_name}")
    
    async def emit_event(self, event_data: Dict[str, Any]) -> None:
        """Emit an event to this trigger"""
        if not self.is_active:
            return
        
        # Check if event matches filter
        if self._matches_filter(event_data):
            await self._event_queue.put(event_data)
    
    async def _process_events(self) -> None:
        """Process events from the queue"""
        try:
            while self.is_active:
                try:
                    # Wait for event with timeout
                    event_data = await asyncio.wait_for(
                        self._event_queue.get(),
                        timeout=1.0
                    )
                    
                    # Check max triggers limit
                    if self.max_triggers > 0 and self._trigger_count >= self.max_triggers:
                        logger.info(f"EventTrigger {self.event_name} reached max triggers limit")
                        break
                    
                    self._trigger_count += 1
                    
                    # Fire trigger
                    context = {
                        "event_data": event_data,
                        "trigger_count": self._trigger_count,
                        "event_name": self.event_name
                    }
                    
                    await self.fire(context)
                    
                except asyncio.TimeoutError:
                    continue  # Continue waiting for events
                    
        except asyncio.CancelledError:
            pass
        except Exception as e:
            logger.error(f"EventTrigger processing failed: {e}")
    
    def _matches_filter(self, event_data: Dict[str, Any]) -> bool:
        """Check if event data matches the filter"""
        if not self.event_filter:
            return True
        
        for key, expected_value in self.event_filter.items():
            if key not in event_data:
                return False
            
            actual_value = event_data[key]
            
            # Simple equality check - could be extended for more complex matching
            if actual_value != expected_value:
                return False
        
        return True


class ConditionTrigger(BaseTrigger):
    """Condition-based trigger"""
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize condition trigger"""
        super().__init__(config)
        
        self.condition_function = config.get("condition_function")
        self.check_interval = config.get("check_interval", 10)  # seconds
        self.max_checks = config.get("max_checks", 0)  # 0 = unlimited
        
        self._check_count = 0
        self._task: Optional[asyncio.Task] = None
        
        logger.info("ConditionTrigger initialized")
    
    async def start(self) -> None:
        """Start the condition trigger"""
        if self.is_active:
            return
        
        if not self.condition_function:
            raise ValueError("condition_function is required for ConditionTrigger")
        
        self.is_active = True
        self._task = asyncio.create_task(self._check_condition())
        
        logger.info("ConditionTrigger started")
    
    async def stop(self) -> None:
        """Stop the condition trigger"""
        if not self.is_active:
            return
        
        self.is_active = False
        
        if self._task and not self._task.done():
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        
        logger.info("ConditionTrigger stopped")
    
    async def _check_condition(self) -> None:
        """Periodically check the condition"""
        try:
            while self.is_active:
                # Check max checks limit
                if self.max_checks > 0 and self._check_count >= self.max_checks:
                    logger.info("ConditionTrigger reached max checks limit")
                    break
                
                self._check_count += 1
                
                try:
                    # Evaluate condition
                    if callable(self.condition_function):
                        condition_result = self.condition_function()
                        if asyncio.iscoroutine(condition_result):
                            condition_result = await condition_result
                    else:
                        # Simple string evaluation (unsafe - use with caution)
                        condition_result = eval(self.condition_function)
                    
                    if condition_result:
                        context = {
                            "condition_result": condition_result,
                            "check_count": self._check_count,
                            "check_time": datetime.now()
                        }
                        
                        await self.fire(context)
                        
                        # Stop after first successful condition unless configured otherwise
                        if not self.config.get("continuous", False):
                            break
                
                except Exception as e:
                    logger.error(f"Condition evaluation failed: {e}")
                
                await asyncio.sleep(self.check_interval)
                
        except asyncio.CancelledError:
            pass
        except Exception as e:
            logger.error(f"ConditionTrigger execution failed: {e}")


class TriggerManager:
    """Manages multiple triggers"""
    
    def __init__(self):
        """Initialize trigger manager"""
        self.triggers: Dict[str, BaseTrigger] = {}
        self.event_triggers: Dict[str, List[EventTrigger]] = {}
        
        logger.info("TriggerManager initialized")
    
    def add_trigger(self, trigger_id: str, trigger: BaseTrigger) -> None:
        """Add a trigger"""
        self.triggers[trigger_id] = trigger
        
        # Index event triggers by event name
        if isinstance(trigger, EventTrigger):
            event_name = trigger.event_name
            if event_name not in self.event_triggers:
                self.event_triggers[event_name] = []
            self.event_triggers[event_name].append(trigger)
        
        logger.info(f"Added trigger: {trigger_id}")
    
    def remove_trigger(self, trigger_id: str) -> bool:
        """Remove a trigger"""
        if trigger_id not in self.triggers:
            return False
        
        trigger = self.triggers[trigger_id]
        
        # Remove from event triggers index
        if isinstance(trigger, EventTrigger):
            event_name = trigger.event_name
            if event_name in self.event_triggers:
                self.event_triggers[event_name].remove(trigger)
                if not self.event_triggers[event_name]:
                    del self.event_triggers[event_name]
        
        del self.triggers[trigger_id]
        logger.info(f"Removed trigger: {trigger_id}")
        return True
    
    async def start_trigger(self, trigger_id: str) -> bool:
        """Start a specific trigger"""
        if trigger_id not in self.triggers:
            return False
        
        await self.triggers[trigger_id].start()
        return True
    
    async def stop_trigger(self, trigger_id: str) -> bool:
        """Stop a specific trigger"""
        if trigger_id not in self.triggers:
            return False
        
        await self.triggers[trigger_id].stop()
        return True
    
    async def start_all_triggers(self) -> None:
        """Start all triggers"""
        for trigger in self.triggers.values():
            await trigger.start()
        
        logger.info("All triggers started")
    
    async def stop_all_triggers(self) -> None:
        """Stop all triggers"""
        for trigger in self.triggers.values():
            await trigger.stop()
        
        logger.info("All triggers stopped")
    
    async def emit_event(self, event_name: str, event_data: Dict[str, Any]) -> None:
        """Emit an event to all matching event triggers"""
        if event_name in self.event_triggers:
            for trigger in self.event_triggers[event_name]:
                await trigger.emit_event(event_data)
    
    def get_trigger_status(self) -> Dict[str, Dict[str, Any]]:
        """Get status of all triggers"""
        status = {}
        
        for trigger_id, trigger in self.triggers.items():
            status[trigger_id] = {
                "type": type(trigger).__name__,
                "active": trigger.is_active,
                "config": trigger.config
            }
        
        return status
