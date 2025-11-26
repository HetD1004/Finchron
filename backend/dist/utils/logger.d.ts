declare class Logger {
    private static getTimestamp;
    private static formatMessage;
    static info(message: any, ...args: any[]): void;
    static error(message: any, ...args: any[]): void;
    static warn(message: any, ...args: any[]): void;
    static debug(message: any, ...args: any[]): void;
    static http(message: any, ...args: any[]): void;
}
export declare const logger: typeof Logger;
export {};
//# sourceMappingURL=logger.d.ts.map