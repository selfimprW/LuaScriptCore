//
//  LSCFunction.m
//  LuaScriptCore
//
//  Created by 冯鸿杰 on 16/10/27.
//  Copyright © 2016年 vimfung. All rights reserved.
//

#import "LSCFunction.h"
#import "LSCFunction_Private.h"
#import "LSCContext_Private.h"
#import "LSCValue_Private.h"
#import "LSCTuple_Private.h"

@implementation LSCFunction

- (instancetype)initWithContext:(LSCContext *)context index:(NSInteger)index
{
    if (self = [super init])
    {
        self.context = context;
        self.linkId = [NSString stringWithFormat:@"%p", self];
        
        //设置Lua对象到_vars_表中
        [self.context.dataExchanger setLubObjectByStackIndex:index objectId:self.linkId];
        //进行引用
        [self.context retainValue:[LSCValue functionValue:self]];
    }
    
    return self;
}

- (void)dealloc
{
    [self.context releaseValue:[LSCValue functionValue:self]];
}

- (LSCValue *)invokeWithArguments:(NSArray<LSCValue *> *)arguments
{
    LSCValue *retValue = nil;
    
    __weak LSCFunction *theFunc = self;
    lua_State *state = self.context.currentSession.state;
    
    int errFuncIndex = [self.context catchLuaException];
    int top = [LSCEngineAdapter getTop:state];
    [self.context.dataExchanger getLuaObject:self];
    
    if ([LSCEngineAdapter isFunction:state index:-1])
    {
        int returnCount = 0;
        
        [arguments enumerateObjectsUsingBlock:^(LSCValue *_Nonnull value, NSUInteger idx, BOOL *_Nonnull stop) {
            
            [value pushWithContext:theFunc.context];
            
        }];
        
        if ([LSCEngineAdapter pCall:state nargs:(int)arguments.count nresults:LUA_MULTRET errfunc:errFuncIndex] == 0)
        {
            returnCount = [LSCEngineAdapter getTop:state] - top;
            if (returnCount > 1)
            {
                LSCTuple *tuple = [[LSCTuple alloc] init];
                for (int i = 1; i <= returnCount; i++)
                {
                    LSCValue *value = [LSCValue valueWithContext:self.context atIndex:top + i];
                    [tuple addReturnValue:[value toObject]];
                }
                retValue = [LSCValue tupleValue:tuple];
            }
            else if (returnCount == 1)
            {
                retValue = [LSCValue valueWithContext:self.context atIndex:-1];
            }
            
        }
        else
        {
            //调用失败
            returnCount = [LSCEngineAdapter getTop:state] - top;
        }
        
        //弹出返回值
        [LSCEngineAdapter pop:state count:returnCount];
    }
    else
    {
        //弹出func
        [LSCEngineAdapter pop:state count:1];
    }
    
    //移除异常捕获方法
    [LSCEngineAdapter remove:state index:errFuncIndex];

    if (!retValue)
    {
        retValue = [LSCValue nilValue];
    }
    
    //释放内存
    [self.context gc];
    
    return retValue;
}

#pragma mark - LSCManagedObjectProtocol

- (BOOL)pushWithContext:(LSCContext *)context
{
    return YES;
}

@end
