import { Request, Response } from 'express';
export declare class AuthController {
    private db;
    constructor();
    register(req: Request, res: Response): Promise<void>;
    login(req: Request, res: Response): Promise<void>;
    googleLogin(req: Request, res: Response): Promise<void>;
    refreshToken(req: Request, res: Response): Promise<void>;
    logout(req: Request, res: Response): Promise<void>;
    private generateToken;
}
//# sourceMappingURL=AuthController.d.ts.map