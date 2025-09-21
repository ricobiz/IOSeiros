
"""
Form Handler - advanced form filling and submission
"""
import asyncio
from typing import Dict, Any, Optional, List, Union
from playwright.async_api import Page, ElementHandle
from loguru import logger

from ..core.exceptions import FormHandlingError


class FormHandler:
    """
    Advanced form handling with validation and auto-fill capabilities
    """
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize form handler"""
        self.config = config
        self.auto_fill = config.get("auto_fill", True)
        self.validation = config.get("validation", True)
        self.submit_delay = config.get("submit_delay", 1000)
        
        # Field type mappings
        self.field_handlers = {
            "text": self._handle_text_field,
            "email": self._handle_email_field,
            "password": self._handle_password_field,
            "number": self._handle_number_field,
            "tel": self._handle_tel_field,
            "url": self._handle_url_field,
            "search": self._handle_search_field,
            "textarea": self._handle_textarea_field,
            "select": self._handle_select_field,
            "checkbox": self._handle_checkbox_field,
            "radio": self._handle_radio_field,
            "file": self._handle_file_field,
            "date": self._handle_date_field,
            "time": self._handle_time_field,
            "datetime-local": self._handle_datetime_field,
            "range": self._handle_range_field,
            "color": self._handle_color_field
        }
        
        logger.info("FormHandler initialized")
    
    async def initialize(self) -> None:
        """Initialize form handler"""
        logger.info("FormHandler ready")
    
    async def fill_form(self, page: Page, form_data: Dict[str, Any], options: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Fill a form with provided data"""
        options = options or {}
        form_selector = options.get("form_selector", "form")
        
        try:
            # Find the form
            form = await page.query_selector(form_selector)
            if not form:
                raise FormHandlingError(f"Form not found: {form_selector}")
            
            # Get all form fields
            fields = await self._get_form_fields(page, form)
            
            results = {}
            filled_count = 0
            
            for field_name, field_value in form_data.items():
                try:
                    field_info = fields.get(field_name)
                    if not field_info:
                        logger.warning(f"Field not found: {field_name}")
                        results[field_name] = {"status": "not_found"}
                        continue
                    
                    # Fill the field based on its type
                    field_type = field_info["type"]
                    handler = self.field_handlers.get(field_type, self._handle_text_field)
                    
                    success = await handler(page, field_info, field_value)
                    
                    if success:
                        filled_count += 1
                        results[field_name] = {"status": "filled", "value": field_value}
                    else:
                        results[field_name] = {"status": "failed"}
                    
                except Exception as e:
                    logger.error(f"Failed to fill field {field_name}: {e}")
                    results[field_name] = {"status": "error", "error": str(e)}
            
            logger.info(f"Form filling completed: {filled_count}/{len(form_data)} fields filled")
            
            return {
                "status": "completed",
                "filled_count": filled_count,
                "total_fields": len(form_data),
                "results": results
            }
            
        except Exception as e:
            logger.error(f"Form filling failed: {e}")
            raise FormHandlingError(f"Form filling failed: {e}")
    
    async def submit_form(self, page: Page, form_selector: str = "form", options: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Submit a form"""
        options = options or {}
        
        try:
            # Find the form
            form = await page.query_selector(form_selector)
            if not form:
                raise FormHandlingError(f"Form not found: {form_selector}")
            
            # Validate form if enabled
            if self.validation:
                validation_result = await self._validate_form(page, form)
                if not validation_result["valid"]:
                    return {
                        "status": "validation_failed",
                        "errors": validation_result["errors"]
                    }
            
            # Wait before submission if configured
            if self.submit_delay > 0:
                await asyncio.sleep(self.submit_delay / 1000)
            
            # Find submit button or use form submission
            submit_button = await form.query_selector('input[type="submit"], button[type="submit"], button:not([type])')
            
            if submit_button:
                await submit_button.click()
                logger.info("Form submitted via submit button")
            else:
                # Use form.submit() as fallback
                await form.evaluate("form => form.submit()")
                logger.info("Form submitted via form.submit()")
            
            # Wait for navigation or response
            wait_for = options.get("wait_for", "networkidle")
            if wait_for == "navigation":
                await page.wait_for_load_state("networkidle")
            elif wait_for == "selector":
                selector = options.get("success_selector")
                if selector:
                    await page.wait_for_selector(selector, timeout=10000)
            
            return {
                "status": "submitted",
                "method": "button" if submit_button else "form"
            }
            
        except Exception as e:
            logger.error(f"Form submission failed: {e}")
            raise FormHandlingError(f"Form submission failed: {e}")
    
    async def _get_form_fields(self, page: Page, form: ElementHandle) -> Dict[str, Dict[str, Any]]:
        """Get all fields in a form"""
        try:
            fields_script = """
                form => {
                    const fields = {};
                    const elements = form.querySelectorAll('input, select, textarea');
                    
                    elements.forEach(element => {
                        const name = element.name || element.id;
                        if (name) {
                            fields[name] = {
                                type: element.type || element.tagName.toLowerCase(),
                                name: name,
                                id: element.id,
                                required: element.required,
                                value: element.value,
                                selector: element.tagName.toLowerCase() + 
                                         (element.id ? '#' + element.id : '') +
                                         (element.name ? '[name="' + element.name + '"]' : '')
                            };
                        }
                    });
                    
                    return fields;
                }
            """
            
            fields = await form.evaluate(fields_script)
            return fields
            
        except Exception as e:
            logger.error(f"Failed to get form fields: {e}")
            return {}
    
    async def _validate_form(self, page: Page, form: ElementHandle) -> Dict[str, Any]:
        """Validate form fields"""
        try:
            validation_script = """
                form => {
                    const errors = [];
                    const elements = form.querySelectorAll('input, select, textarea');
                    
                    elements.forEach(element => {
                        if (element.required && !element.value.trim()) {
                            errors.push({
                                field: element.name || element.id,
                                error: 'Required field is empty'
                            });
                        }
                        
                        if (element.type === 'email' && element.value) {
                            const emailRegex = /^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$/;
                            if (!emailRegex.test(element.value)) {
                                errors.push({
                                    field: element.name || element.id,
                                    error: 'Invalid email format'
                                });
                            }
                        }
                        
                        if (element.type === 'url' && element.value) {
                            try {
                                new URL(element.value);
                            } catch {
                                errors.push({
                                    field: element.name || element.id,
                                    error: 'Invalid URL format'
                                });
                            }
                        }
                    });
                    
                    return {
                        valid: errors.length === 0,
                        errors: errors
                    };
                }
            """
            
            return await form.evaluate(validation_script)
            
        except Exception as e:
            logger.error(f"Form validation failed: {e}")
            return {"valid": False, "errors": [{"error": str(e)}]}
    
    # Field handlers
    async def _handle_text_field(self, page: Page, field_info: Dict[str, Any], value: str) -> bool:
        """Handle text input fields"""
        try:
            selector = field_info["selector"]
            await page.fill(selector, str(value))
            return True
        except Exception as e:
            logger.error(f"Failed to fill text field: {e}")
            return False
    
    async def _handle_email_field(self, page: Page, field_info: Dict[str, Any], value: str) -> bool:
        """Handle email input fields"""
        return await self._handle_text_field(page, field_info, value)
    
    async def _handle_password_field(self, page: Page, field_info: Dict[str, Any], value: str) -> bool:
        """Handle password input fields"""
        return await self._handle_text_field(page, field_info, value)
    
    async def _handle_number_field(self, page: Page, field_info: Dict[str, Any], value: Union[str, int, float]) -> bool:
        """Handle number input fields"""
        return await self._handle_text_field(page, field_info, str(value))
    
    async def _handle_tel_field(self, page: Page, field_info: Dict[str, Any], value: str) -> bool:
        """Handle telephone input fields"""
        return await self._handle_text_field(page, field_info, value)
    
    async def _handle_url_field(self, page: Page, field_info: Dict[str, Any], value: str) -> bool:
        """Handle URL input fields"""
        return await self._handle_text_field(page, field_info, value)
    
    async def _handle_search_field(self, page: Page, field_info: Dict[str, Any], value: str) -> bool:
        """Handle search input fields"""
        return await self._handle_text_field(page, field_info, value)
    
    async def _handle_textarea_field(self, page: Page, field_info: Dict[str, Any], value: str) -> bool:
        """Handle textarea fields"""
        return await self._handle_text_field(page, field_info, value)
    
    async def _handle_select_field(self, page: Page, field_info: Dict[str, Any], value: Union[str, List[str]]) -> bool:
        """Handle select fields"""
        try:
            selector = field_info["selector"]
            if isinstance(value, list):
                await page.select_option(selector, value)
            else:
                await page.select_option(selector, value)
            return True
        except Exception as e:
            logger.error(f"Failed to select option: {e}")
            return False
    
    async def _handle_checkbox_field(self, page: Page, field_info: Dict[str, Any], value: bool) -> bool:
        """Handle checkbox fields"""
        try:
            selector = field_info["selector"]
            if value:
                await page.check(selector)
            else:
                await page.uncheck(selector)
            return True
        except Exception as e:
            logger.error(f"Failed to handle checkbox: {e}")
            return False
    
    async def _handle_radio_field(self, page: Page, field_info: Dict[str, Any], value: str) -> bool:
        """Handle radio button fields"""
        try:
            name = field_info["name"]
            selector = f'input[name="{name}"][value="{value}"]'
            await page.check(selector)
            return True
        except Exception as e:
            logger.error(f"Failed to select radio button: {e}")
            return False
    
    async def _handle_file_field(self, page: Page, field_info: Dict[str, Any], value: Union[str, List[str]]) -> bool:
        """Handle file input fields"""
        try:
            selector = field_info["selector"]
            if isinstance(value, list):
                await page.set_input_files(selector, value)
            else:
                await page.set_input_files(selector, value)
            return True
        except Exception as e:
            logger.error(f"Failed to upload file: {e}")
            return False
    
    async def _handle_date_field(self, page: Page, field_info: Dict[str, Any], value: str) -> bool:
        """Handle date input fields"""
        return await self._handle_text_field(page, field_info, value)
    
    async def _handle_time_field(self, page: Page, field_info: Dict[str, Any], value: str) -> bool:
        """Handle time input fields"""
        return await self._handle_text_field(page, field_info, value)
    
    async def _handle_datetime_field(self, page: Page, field_info: Dict[str, Any], value: str) -> bool:
        """Handle datetime-local input fields"""
        return await self._handle_text_field(page, field_info, value)
    
    async def _handle_range_field(self, page: Page, field_info: Dict[str, Any], value: Union[str, int, float]) -> bool:
        """Handle range input fields"""
        return await self._handle_text_field(page, field_info, str(value))
    
    async def _handle_color_field(self, page: Page, field_info: Dict[str, Any], value: str) -> bool:
        """Handle color input fields"""
        return await self._handle_text_field(page, field_info, value)
