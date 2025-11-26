"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.logger = void 0;
// Simple logger utility for development
class Logger {
    static getTimestamp() {
        return new Date().toISOString();
    }
    static formatMessage(level, message, ...args) {
        const timestamp = this.getTimestamp();
        const formattedMessage = typeof message === 'string' ? message : JSON.stringify(message);
        const additionalArgs = args.length > 0 ? ' ' + args.map(arg => typeof arg === 'string' ? arg : JSON.stringify(arg)).join(' ') : '';
        return `[${timestamp}] ${level.toUpperCase()}: ${formattedMessage}${additionalArgs}`;
    }
    static info(message, ...args) {
        console.log(this.formatMessage('info', message, ...args));
    }
    static error(message, ...args) {
        console.error(this.formatMessage('error', message, ...args));
    }
    static warn(message, ...args) {
        console.warn(this.formatMessage('warn', message, ...args));
    }
    static debug(message, ...args) {
        if (process.env.NODE_ENV === 'development' || process.env.LOG_LEVEL === 'debug') {
            console.debug(this.formatMessage('debug', message, ...args));
        }
    }
    static http(message, ...args) {
        console.log(this.formatMessage('http', message, ...args));
    }
}
exports.logger = Logger;
//# sourceMappingURL=logger.js.map