import { KeyTokenService } from './keyToken.service';
import { ShopService } from './shop.service';
import { IKeyToken } from '../models/keytoken.model';
export declare const RoleShop: {
    readonly SHOP: "SHOP";
    readonly WRITER: "WRITER";
    readonly EDITOR: "EDITOR";
    readonly ADMIN: "ADMIN";
};
export interface IAccessService {
    handlerRefreshTokenV2(params: {
        refreshToken: string;
        user: any;
        keyStore: IKeyToken;
    }): Promise<{
        user: any;
        tokens: any;
    }>;
    handlerRefreshToken(refreshToken: string): Promise<{
        user: any;
        tokens: any;
    }>;
    logout(keyStore: any): Promise<boolean>;
    login(params: {
        email: string;
        password: string;
        refreshToken?: string;
    }): Promise<{
        shop: any;
        tokens: any;
    }>;
    signUp(params: {
        name: string;
        email: string;
        password: string;
    }): Promise<{
        shop: any;
        tokens: any;
    } | {
        code: number;
        metadata: null;
    }>;
}
export declare class AccessService implements IAccessService {
    private keyTokenService;
    private shopService;
    constructor(keyTokenService: KeyTokenService, shopService: ShopService);
    handlerRefreshTokenV2({ refreshToken, user, keyStore, }: {
        refreshToken: string;
        user: any;
        keyStore: IKeyToken;
    }): Promise<{
        user: any;
        tokens: any;
    }>;
    handlerRefreshToken(refreshToken: string): Promise<{
        user: any;
        tokens: any;
    }>;
    logout(keyStore: any): Promise<boolean>;
    login({ email, password, refreshToken, }: {
        email: string;
        password: string;
        refreshToken?: string;
    }): Promise<{
        shop: any;
        tokens: any;
    }>;
    signUp({ name, email, password, }: {
        name: string;
        email: string;
        password: string;
    }): Promise<{
        shop: any;
        tokens: any;
    } | {
        code: number;
        metadata: null;
    }>;
}
//# sourceMappingURL=access.service.d.ts.map