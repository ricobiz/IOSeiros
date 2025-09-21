
/**
 * UI Utilities and Helpers
 */

class UIManager {
    constructor() {
        this.modals = {};
        this.tooltips = {};
        this.dropdowns = {};
        
        this.init();
    }
    
    init() {
        this.setupGlobalEventListeners();
        this.initializeTooltips();
        this.initializeDropdowns();
        this.setupKeyboardShortcuts();
    }
    
    setupGlobalEventListeners() {
        // Close dropdowns when clicking outside
        document.addEventListener('click', (e) => {
            this.closeAllDropdowns(e.target);
        });
        
        // Handle escape key for modals and dropdowns
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                this.closeAllModals();
                this.closeAllDropdowns();
            }
        });
        
        // Handle form submissions
        document.addEventListener('submit', (e) => {
            this.handleFormSubmission(e);
        });
        
        // Handle button clicks with loading states
        document.addEventListener('click', (e) => {
            if (e.target.matches('.btn[data-loading]')) {
                this.handleLoadingButton(e.target);
            }
        });
    }
    
    setupKeyboardShortcuts() {
        const shortcuts = {
            'ctrl+k': () => this.showCommandPalette(),
            'ctrl+/': () => this.showKeyboardShortcuts(),
            'ctrl+shift+d': () => this.toggleDarkMode(),
            'f11': () => this.toggleFullscreen()
        };
        
        document.addEventListener('keydown', (e) => {
            const key = this.getKeyboardShortcut(e);
            if (shortcuts[key]) {
                e.preventDefault();
                shortcuts[key]();
            }
        });
    }
    
    getKeyboardShortcut(e) {
        const parts = [];
        if (e.ctrlKey) parts.push('ctrl');
        if (e.shiftKey) parts.push('shift');
        if (e.altKey) parts.push('alt');
        if (e.metaKey) parts.push('meta');
        
        if (e.key !== 'Control' && e.key !== 'Shift' && e.key !== 'Alt' && e.key !== 'Meta') {
            parts.push(e.key.toLowerCase());
        }
        
        return parts.join('+');
    }
    
    // Modal Management
    showModal(modalId, options = {}) {
        const modal = document.getElementById(modalId);
        if (!modal) return false;
        
        // Store modal options
        this.modals[modalId] = {
            element: modal,
            options: options
        };
        
        // Show modal
        modal.classList.add('show');
        document.body.style.overflow = 'hidden';
        
        // Focus first input if available
        const firstInput = modal.querySelector('input, select, textarea, button');
        if (firstInput) {
            setTimeout(() => firstInput.focus(), 100);
        }
        
        // Trigger show event
        this.triggerEvent(modal, 'modal:show', { modalId, options });
        
        return true;
    }
    
    closeModal(modalId) {
        const modal = document.getElementById(modalId);
        if (!modal) return false;
        
        modal.classList.remove('show');
        document.body.style.overflow = '';
        
        // Clean up
        delete this.modals[modalId];
        
        // Trigger hide event
        this.triggerEvent(modal, 'modal:hide', { modalId });
        
        return true;
    }
    
    closeAllModals() {
        Object.keys(this.modals).forEach(modalId => {
            this.closeModal(modalId);
        });
    }
    
    // Dropdown Management
    initializeDropdowns() {
        document.querySelectorAll('[data-dropdown]').forEach(trigger => {
            const dropdownId = trigger.getAttribute('data-dropdown');
            const dropdown = document.getElementById(dropdownId);
            
            if (dropdown) {
                trigger.addEventListener('click', (e) => {
                    e.stopPropagation();
                    this.toggleDropdown(dropdownId);
                });
                
                this.dropdowns[dropdownId] = {
                    trigger: trigger,
                    dropdown: dropdown
                };
            }
        });
    }
    
    toggleDropdown(dropdownId) {
        const dropdown = document.getElementById(dropdownId);
        if (!dropdown) return false;
        
        const isOpen = dropdown.classList.contains('show');
        
        // Close all other dropdowns
        this.closeAllDropdowns();
        
        if (!isOpen) {
            dropdown.classList.add('show');
            this.positionDropdown(dropdown);
        }
        
        return !isOpen;
    }
    
    closeDropdown(dropdownId) {
        const dropdown = document.getElementById(dropdownId);
        if (dropdown) {
            dropdown.classList.remove('show');
        }
    }
    
    closeAllDropdowns(except = null) {
        Object.keys(this.dropdowns).forEach(dropdownId => {
            const dropdown = document.getElementById(dropdownId);
            if (dropdown && dropdown !== except && !dropdown.contains(except)) {
                this.closeDropdown(dropdownId);
            }
        });
    }
    
    positionDropdown(dropdown) {
        const trigger = dropdown.previousElementSibling;
        if (!trigger) return;
        
        const triggerRect = trigger.getBoundingClientRect();
        const dropdownRect = dropdown.getBoundingClientRect();
        const viewportHeight = window.innerHeight;
        
        // Position below trigger by default
        let top = triggerRect.bottom + 5;
        
        // If dropdown would go below viewport, position above
        if (top + dropdownRect.height > viewportHeight) {
            top = triggerRect.top - dropdownRect.height - 5;
        }
        
        dropdown.style.top = `${top}px`;
        dropdown.style.left = `${triggerRect.left}px`;
    }
    
    // Tooltip Management
    initializeTooltips() {
        document.querySelectorAll('[data-tooltip]').forEach(element => {
            this.createTooltip(element);
        });
    }
    
    createTooltip(element) {
        const text = element.getAttribute('data-tooltip');
        const position = element.getAttribute('data-tooltip-position') || 'top';
        
        let tooltip = null;
        
        element.addEventListener('mouseenter', () => {
            tooltip = this.showTooltip(element, text, position);
        });
        
        element.addEventListener('mouseleave', () => {
            if (tooltip) {
                tooltip.remove();
                tooltip = null;
            }
        });
    }
    
    showTooltip(element, text, position = 'top') {
        const tooltip = document.createElement('div');
        tooltip.className = `tooltip tooltip-${position}`;
        tooltip.textContent = text;
        
        document.body.appendChild(tooltip);
        
        const elementRect = element.getBoundingClientRect();
        const tooltipRect = tooltip.getBoundingClientRect();
        
        let top, left;
        
        switch (position) {
            case 'top':
                top = elementRect.top - tooltipRect.height - 5;
                left = elementRect.left + (elementRect.width - tooltipRect.width) / 2;
                break;
            case 'bottom':
                top = elementRect.bottom + 5;
                left = elementRect.left + (elementRect.width - tooltipRect.width) / 2;
                break;
            case 'left':
                top = elementRect.top + (elementRect.height - tooltipRect.height) / 2;
                left = elementRect.left - tooltipRect.width - 5;
                break;
            case 'right':
                top = elementRect.top + (elementRect.height - tooltipRect.height) / 2;
                left = elementRect.right + 5;
                break;
        }
        
        tooltip.style.top = `${top}px`;
        tooltip.style.left = `${left}px`;
        
        return tooltip;
    }
    
    // Form Handling
    handleFormSubmission(e) {
        const form = e.target;
        if (!form.matches('form[data-ajax]')) return;
        
        e.preventDefault();
        
        const url = form.action || window.location.href;
        const method = form.method || 'POST';
        const formData = new FormData(form);
        
        this.submitForm(url, method, formData, form);
    }
    
    async submitForm(url, method, data, form) {
        const submitButton = form.querySelector('button[type="submit"]');
        
        try {
            // Show loading state
            if (submitButton) {
                this.setButtonLoading(submitButton, true);
            }
            
            const response = await fetch(url, {
                method: method,
                body: data
            });
            
            const result = await response.json();
            
            if (response.ok) {
                this.triggerEvent(form, 'form:success', result);
                this.showNotification('Form submitted successfully', 'success');
            } else {
                this.triggerEvent(form, 'form:error', result);
                this.showNotification(result.message || 'Form submission failed', 'error');
            }
            
        } catch (error) {
            console.error('Form submission error:', error);
            this.triggerEvent(form, 'form:error', { error: error.message });
            this.showNotification('Form submission failed', 'error');
        } finally {
            // Hide loading state
            if (submitButton) {
                this.setButtonLoading(submitButton, false);
            }
        }
    }
    
    // Button Loading States
    handleLoadingButton(button) {
        const loadingText = button.getAttribute('data-loading-text') || 'Loading...';
        const originalText = button.textContent;
        
        button.setAttribute('data-original-text', originalText);
        this.setButtonLoading(button, true, loadingText);
        
        // Auto-restore after 5 seconds if not manually restored
        setTimeout(() => {
            if (button.hasAttribute('data-loading')) {
                this.setButtonLoading(button, false);
            }
        }, 5000);
    }
    
    setButtonLoading(button, loading, loadingText = 'Loading...') {
        if (loading) {
            const originalText = button.getAttribute('data-original-text') || button.textContent;
            button.setAttribute('data-original-text', originalText);
            button.setAttribute('data-loading', 'true');
            button.disabled = true;
            button.innerHTML = `<i class="fas fa-spinner fa-spin"></i> ${loadingText}`;
        } else {
            const originalText = button.getAttribute('data-original-text');
            button.removeAttribute('data-loading');
            button.disabled = false;
            button.textContent = originalText || 'Submit';
            button.removeAttribute('data-original-text');
        }
    }
    
    // Notifications
    showNotification(message, type = 'info', duration = 5000) {
        if (window.app) {
            window.app.showToast(message, type, duration);
        } else {
            // Fallback notification
            console.log(`${type.toUpperCase()}: ${message}`);
        }
    }
    
    // Theme Management
    toggleDarkMode() {
        const currentTheme = document.documentElement.getAttribute('data-theme');
        const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
        
        document.documentElement.setAttribute('data-theme', newTheme);
        
        if (window.app) {
            window.app.settings.theme = newTheme;
            window.app.saveSettings();
        }
        
        this.showNotification(`Switched to ${newTheme} theme`, 'info');
    }
    
    // Fullscreen Management
    toggleFullscreen() {
        if (!document.fullscreenElement) {
            document.documentElement.requestFullscreen().catch(err => {
                console.error('Error attempting to enable fullscreen:', err);
            });
        } else {
            document.exitFullscreen();
        }
    }
    
    // Command Palette
    showCommandPalette() {
        // This would show a command palette modal
        this.showNotification('Command palette coming soon', 'info');
    }
    
    showKeyboardShortcuts() {
        const shortcuts = [
            'Ctrl+K - Command Palette',
            'Ctrl+/ - Show Shortcuts',
            'Ctrl+Shift+D - Toggle Dark Mode',
            'F11 - Toggle Fullscreen',
            'Ctrl+1-4 - Switch Views',
            'Ctrl+R - Refresh Current View',
            'Escape - Close Modals/Dropdowns'
        ];
        
        const message = shortcuts.join('\n');
        this.showNotification(message, 'info', 10000);
    }
    
    // Utility Functions
    triggerEvent(element, eventName, detail = {}) {
        const event = new CustomEvent(eventName, {
            detail: detail,
            bubbles: true,
            cancelable: true
        });
        element.dispatchEvent(event);
    }
    
    debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }
    
    throttle(func, limit) {
        let inThrottle;
        return function() {
            const args = arguments;
            const context = this;
            if (!inThrottle) {
                func.apply(context, args);
                inThrottle = true;
                setTimeout(() => inThrottle = false, limit);
            }
        };
    }
    
    formatBytes(bytes, decimals = 2) {
        if (bytes === 0) return '0 Bytes';
        
        const k = 1024;
        const dm = decimals < 0 ? 0 : decimals;
        const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
        
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        
        return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
    }
    
    formatNumber(num, decimals = 0) {
        return new Intl.NumberFormat('en-US', {
            minimumFractionDigits: decimals,
            maximumFractionDigits: decimals
        }).format(num);
    }
    
    formatPercent(value, decimals = 1) {
        return `${value.toFixed(decimals)}%`;
    }
    
    formatDuration(seconds) {
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        const secs = Math.floor(seconds % 60);
        
        if (hours > 0) {
            return `${hours}h ${minutes}m ${secs}s`;
        } else if (minutes > 0) {
            return `${minutes}m ${secs}s`;
        } else {
            return `${secs}s`;
        }
    }
    
    copyToClipboard(text) {
        if (navigator.clipboard) {
            navigator.clipboard.writeText(text).then(() => {
                this.showNotification('Copied to clipboard', 'success');
            }).catch(err => {
                console.error('Failed to copy to clipboard:', err);
                this.showNotification('Failed to copy to clipboard', 'error');
            });
        } else {
            // Fallback for older browsers
            const textArea = document.createElement('textarea');
            textArea.value = text;
            document.body.appendChild(textArea);
            textArea.select();
            
            try {
                document.execCommand('copy');
                this.showNotification('Copied to clipboard', 'success');
            } catch (err) {
                console.error('Failed to copy to clipboard:', err);
                this.showNotification('Failed to copy to clipboard', 'error');
            }
            
            document.body.removeChild(textArea);
        }
    }
    
    downloadFile(data, filename, type = 'text/plain') {
        const blob = new Blob([data], { type });
        const url = window.URL.createObjectURL(blob);
        
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        
        window.URL.revokeObjectURL(url);
        document.body.removeChild(a);
    }
    
    // Animation Utilities
    fadeIn(element, duration = 300) {
        element.style.opacity = '0';
        element.style.display = 'block';
        
        const start = performance.now();
        
        const animate = (currentTime) => {
            const elapsed = currentTime - start;
            const progress = Math.min(elapsed / duration, 1);
            
            element.style.opacity = progress.toString();
            
            if (progress < 1) {
                requestAnimationFrame(animate);
            }
        };
        
        requestAnimationFrame(animate);
    }
    
    fadeOut(element, duration = 300) {
        const start = performance.now();
        const startOpacity = parseFloat(element.style.opacity) || 1;
        
        const animate = (currentTime) => {
            const elapsed = currentTime - start;
            const progress = Math.min(elapsed / duration, 1);
            
            element.style.opacity = (startOpacity * (1 - progress)).toString();
            
            if (progress < 1) {
                requestAnimationFrame(animate);
            } else {
                element.style.display = 'none';
            }
        };
        
        requestAnimationFrame(animate);
    }
    
    slideDown(element, duration = 300) {
        element.style.height = '0';
        element.style.overflow = 'hidden';
        element.style.display = 'block';
        
        const targetHeight = element.scrollHeight;
        const start = performance.now();
        
        const animate = (currentTime) => {
            const elapsed = currentTime - start;
            const progress = Math.min(elapsed / duration, 1);
            
            element.style.height = (targetHeight * progress) + 'px';
            
            if (progress < 1) {
                requestAnimationFrame(animate);
            } else {
                element.style.height = '';
                element.style.overflow = '';
            }
        };
        
        requestAnimationFrame(animate);
    }
    
    slideUp(element, duration = 300) {
        const startHeight = element.offsetHeight;
        const start = performance.now();
        
        element.style.overflow = 'hidden';
        
        const animate = (currentTime) => {
            const elapsed = currentTime - start;
            const progress = Math.min(elapsed / duration, 1);
            
            element.style.height = (startHeight * (1 - progress)) + 'px';
            
            if (progress < 1) {
                requestAnimationFrame(animate);
            } else {
                element.style.display = 'none';
                element.style.height = '';
                element.style.overflow = '';
            }
        };
        
        requestAnimationFrame(animate);
    }
}

// Initialize UI Manager
document.addEventListener('DOMContentLoaded', () => {
    window.uiManager = new UIManager();
});

// Export utility functions globally
window.UIUtils = {
    formatBytes: (bytes, decimals) => window.uiManager?.formatBytes(bytes, decimals),
    formatNumber: (num, decimals) => window.uiManager?.formatNumber(num, decimals),
    formatPercent: (value, decimals) => window.uiManager?.formatPercent(value, decimals),
    formatDuration: (seconds) => window.uiManager?.formatDuration(seconds),
    copyToClipboard: (text) => window.uiManager?.copyToClipboard(text),
    downloadFile: (data, filename, type) => window.uiManager?.downloadFile(data, filename, type),
    debounce: (func, wait) => window.uiManager?.debounce(func, wait),
    throttle: (func, limit) => window.uiManager?.throttle(func, limit)
};
