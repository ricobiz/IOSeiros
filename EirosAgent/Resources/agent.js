/**
 * Eiros Agent Browser Automation Script
 * Created by DeepAgent on 2025-09-21
 * 
 * This script provides intelligent browser automation capabilities
 * for the Eiros Agent iOS app.
 */

window.EirosAgent = (function() {
    'use strict';
    
    // Configuration
    const config = {
        highlightColor: '#FF6B6B',
        highlightDuration: 2000,
        debugMode: false
    };
    
    // Utility functions
    const utils = {
        log: function(message, data = null) {
            if (config.debugMode) {
                console.log('[EirosAgent]', message, data);
            }
        },
        
        sendMessage: function(type, data = {}) {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.eirosAgent) {
                window.webkit.messageHandlers.eirosAgent.postMessage({
                    type: type,
                    timestamp: Date.now(),
                    url: window.location.href,
                    ...data
                });
            }
        },
        
        highlightElement: function(element) {
            if (!element) return;
            
            const originalStyle = element.style.cssText;
            element.style.cssText += `
                outline: 3px solid ${config.highlightColor} !important;
                outline-offset: 2px !important;
            `;
            
            setTimeout(() => {
                element.style.cssText = originalStyle;
            }, config.highlightDuration);
        },
        
        isVisible: function(element) {
            return !!(element.offsetWidth || element.offsetHeight || element.getClientRects().length);
        },
        
        getElementPath: function(element) {
            const path = [];
            while (element.nodeType === Node.ELEMENT_NODE) {
                let selector = element.nodeName.toLowerCase();
                if (element.id) {
                    selector += '#' + element.id;
                } else if (element.className) {
                    selector += '.' + element.className.split(' ').join('.');
                }
                path.unshift(selector);
                element = element.parentNode;
            }
            return path.join(' > ');
        }
    };
    
    // Core automation functions
    const automation = {
        clickElement: function(selector) {
            try {
                const element = document.querySelector(selector);
                if (element && utils.isVisible(element)) {
                    utils.highlightElement(element);
                    element.click();
                    utils.sendMessage('elementClicked', {
                        selector: selector,
                        element: utils.getElementPath(element),
                        success: true
                    });
                    return true;
                }
            } catch (error) {
                utils.log('Click element error:', error);
                utils.sendMessage('error', {
                    action: 'clickElement',
                    selector: selector,
                    error: error.message
                });
            }
            return false;
        },
        
        typeText: function(text, selector) {
            try {
                const element = document.querySelector(selector);
                if (element && utils.isVisible(element)) {
                    utils.highlightElement(element);
                    
                    // Focus the element first
                    element.focus();
                    
                    // Set the value
                    element.value = text;
                    
                    // Trigger input events
                    const events = ['input', 'change', 'keyup'];
                    events.forEach(eventType => {
                        element.dispatchEvent(new Event(eventType, { bubbles: true }));
                    });
                    
                    utils.sendMessage('textTyped', {
                        selector: selector,
                        text: text,
                        success: true
                    });
                    return true;
                }
            } catch (error) {
                utils.log('Type text error:', error);
                utils.sendMessage('error', {
                    action: 'typeText',
                    selector: selector,
                    error: error.message
                });
            }
            return false;
        },
        
        fillForm: function(formData) {
            try {
                let successCount = 0;
                for (const [selector, value] of Object.entries(formData)) {
                    if (automation.typeText(value, selector)) {
                        successCount++;
                    }
                }
                
                utils.sendMessage('formFilled', {
                    totalFields: Object.keys(formData).length,
                    filledFields: successCount,
                    success: successCount > 0
                });
                
                return successCount;
            } catch (error) {
                utils.log('Fill form error:', error);
                utils.sendMessage('error', {
                    action: 'fillForm',
                    error: error.message
                });
            }
            return 0;
        },
        
        scrollToElement: function(selector) {
            try {
                const element = document.querySelector(selector);
                if (element) {
                    element.scrollIntoView({ behavior: 'smooth', block: 'center' });
                    utils.highlightElement(element);
                    utils.sendMessage('scrolledToElement', {
                        selector: selector,
                        success: true
                    });
                    return true;
                }
            } catch (error) {
                utils.log('Scroll to element error:', error);
            }
            return false;
        }
    };
    
    // Page analysis functions
    const analysis = {
        getPageStructure: function() {
            return {
                title: document.title,
                url: window.location.href,
                domain: window.location.hostname,
                readyState: document.readyState,
                viewport: {
                    width: window.innerWidth,
                    height: window.innerHeight
                }
            };
        },
        
        getInteractiveElements: function() {
            const selectors = [
                'button',
                'input[type="button"]',
                'input[type="submit"]',
                'a[href]',
                'select',
                'input[type="text"]',
                'input[type="email"]',
                'input[type="password"]',
                'textarea',
                '[onclick]',
                '[role="button"]'
            ];
            
            const elements = [];
            selectors.forEach(selector => {
                document.querySelectorAll(selector).forEach(element => {
                    if (utils.isVisible(element)) {
                        elements.push({
                            type: element.tagName.toLowerCase(),
                            selector: utils.getElementPath(element),
                            text: element.textContent?.trim().substring(0, 100) || '',
                            id: element.id || null,
                            className: element.className || null,
                            href: element.href || null,
                            placeholder: element.placeholder || null,
                            bounds: element.getBoundingClientRect()
                        });
                    }
                });
            });
            
            return elements;
        },
        
        getFormFields: function() {
            const forms = Array.from(document.forms).map(form => {
                const fields = Array.from(form.elements).map(field => ({
                    name: field.name,
                    type: field.type,
                    placeholder: field.placeholder || null,
                    required: field.required,
                    selector: utils.getElementPath(field),
                    value: field.value
                }));
                
                return {
                    action: form.action,
                    method: form.method,
                    selector: utils.getElementPath(form),
                    fields: fields
                };
            });
            
            return forms;
        },
        
        getPageContent: function() {
            const headings = Array.from(document.querySelectorAll('h1, h2, h3, h4, h5, h6')).map(h => ({
                level: parseInt(h.tagName[1]),
                text: h.textContent.trim(),
                selector: utils.getElementPath(h)
            }));
            
            const links = Array.from(document.links).map(link => ({
                href: link.href,
                text: link.textContent.trim(),
                selector: utils.getElementPath(link)
            }));
            
            const images = Array.from(document.images).map(img => ({
                src: img.src,
                alt: img.alt,
                selector: utils.getElementPath(img)
            }));
            
            return {
                structure: analysis.getPageStructure(),
                headings: headings,
                links: links,
                images: images,
                forms: analysis.getFormFields(),
                interactiveElements: analysis.getInteractiveElements(),
                bodyText: document.body.innerText.substring(0, 5000) // Limit text size
            };
        },
        
        analyzeCurrentPage: function() {
            try {
                const pageData = analysis.getPageContent();
                utils.sendMessage('pageAnalysis', {
                    data: pageData,
                    success: true
                });
                return pageData;
            } catch (error) {
                utils.log('Page analysis error:', error);
                utils.sendMessage('error', {
                    action: 'analyzeCurrentPage',
                    error: error.message
                });
                return null;
            }
        }
    };
    
    // Smart suggestions based on page content
    const suggestions = {
        getActionSuggestions: function() {
            const elements = analysis.getInteractiveElements();
            const forms = analysis.getFormFields();
            const suggestions = [];
            
            // Suggest filling forms
            if (forms.length > 0) {
                suggestions.push({
                    type: 'fillForm',
                    description: `Fill form with ${forms[0].fields.length} fields`,
                    confidence: 0.8
                });
            }
            
            // Suggest clicking common buttons
            const commonButtons = elements.filter(el => 
                ['button', 'input'].includes(el.type) && 
                ['login', 'submit', 'search', 'sign in', 'continue'].some(keyword => 
                    el.text.toLowerCase().includes(keyword)
                )
            );
            
            if (commonButtons.length > 0) {
                suggestions.push({
                    type: 'clickButton',
                    description: `Click "${commonButtons[0].text}"`,
                    selector: commonButtons[0].selector,
                    confidence: 0.7
                });
            }
            
            return suggestions;
        }
    };
    
    // Event listeners
    function setupEventListeners() {
        // Monitor page changes
        const observer = new MutationObserver(function(mutations) {
            if (mutations.length > 5) { // Only for significant changes
                utils.sendMessage('pageChanged', {
                    mutations: mutations.length
                });
            }
        });
        
        observer.observe(document.body, {
            childList: true,
            subtree: true,
            attributes: true
        });
        
        // Monitor navigation
        window.addEventListener('beforeunload', function() {
            utils.sendMessage('pageLeaving', {
                url: window.location.href
            });
        });
    }
    
    // Initialize when DOM is ready
    function initialize() {
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', initialize);
            return;
        }
        
        utils.log('Eiros Agent initialized');
        setupEventListeners();
        
        // Send initial page load notification
        utils.sendMessage('agentReady', {
            url: window.location.href,
            title: document.title
        });
        
        // Auto-analyze after a short delay
        setTimeout(() => {
            analysis.analyzeCurrentPage();
        }, 1000);
    }
    
    // Public API
    return {
        // Automation functions
        clickElement: automation.clickElement,
        typeText: automation.typeText,
        fillForm: automation.fillForm,
        scrollToElement: automation.scrollToElement,
        
        // Analysis functions
        getPageContent: analysis.getPageContent,
        getInteractiveElements: analysis.getInteractiveElements,
        getFormFields: analysis.getFormFields,
        analyzeCurrentPage: analysis.analyzeCurrentPage,
        
        // Suggestions
        getActionSuggestions: suggestions.getActionSuggestions,
        
        // Utilities
        highlightElement: utils.highlightElement,
        setDebugMode: function(enabled) { config.debugMode = enabled; },
        
        // Initialize
        init: initialize
    };
})();

// Auto-initialize
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', window.EirosAgent.init);
} else {
    window.EirosAgent.init();
}
