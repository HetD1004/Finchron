import express from 'express';
declare class Server {
    private app;
    private port;
    private database;
    constructor();
    private initializeMiddleware;
    private initializeRoutes;
    private initializeErrorHandling;
    start(): Promise<void>;
    getApp(): express.Application;
    stop(): Promise<void>;
}
export default Server;
//# sourceMappingURL=server.d.ts.map