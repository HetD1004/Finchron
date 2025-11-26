// Simple logger utility for development
class Logger {
  private static getTimestamp(): string {
    return new Date().toISOString();
  }

  private static formatMessage(level: string, message: any, ...args: any[]): string {
    const timestamp = this.getTimestamp();
    const formattedMessage = typeof message === 'string' ? message : JSON.stringify(message);
    const additionalArgs = args.length > 0 ? ' ' + args.map(arg => 
      typeof arg === 'string' ? arg : JSON.stringify(arg)
    ).join(' ') : '';
    
    return `[${timestamp}] ${level.toUpperCase()}: ${formattedMessage}${additionalArgs}`;
  }

  static info(message: any, ...args: any[]): void {
    console.log(this.formatMessage('info', message, ...args));
  }

  static error(message: any, ...args: any[]): void {
    console.error(this.formatMessage('error', message, ...args));
  }

  static warn(message: any, ...args: any[]): void {
    console.warn(this.formatMessage('warn', message, ...args));
  }

  static debug(message: any, ...args: any[]): void {
    if (process.env.NODE_ENV === 'development' || process.env.LOG_LEVEL === 'debug') {
      console.debug(this.formatMessage('debug', message, ...args));
    }
  }

  static http(message: any, ...args: any[]): void {
    console.log(this.formatMessage('http', message, ...args));
  }
}

export const logger = Logger;
