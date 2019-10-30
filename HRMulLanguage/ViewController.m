//
//  ViewController.m
//  HRMulLanguage
//
//  Created by ZhangHeng on 2016/12/13.
//  Copyright © 2016年 ZhangHeng. All rights reserved.
//

#import "ViewController.h"
#import <GDataXML-HTML/GDataXMLNode.h>

@interface ViewController ()
{
    //保存excel里按竖行排列的数组
    NSMutableArray  *mainDataArray;
    //每条竖着的单条信息
    NSMutableArray  *listRow;
    
    NSMutableArray *allDatas;
    
    IBOutlet UITextView     *outputText;
}
@property (strong, nonatomic) NSDictionary *pairs;
@property (strong, nonatomic) NSMutableSet *exits;
@property (strong, nonatomic) NSDictionary *countryList;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    _exits = [NSMutableSet new];
    
    _countryList = @{
        @1: @"",
        @2: @"English",
        @3: @"Spanish",
        @4: @"Portuguese",
        @5: @"French",
        @6: @"German",
        @7: @"Italian",
        @8: @"Russian",
        @9: @"Danish",
        @10: @"Norwegian",
        @11: @"Swedish",
        @12: @"Romanian",
        @13: @"Bulgarian",
        @14: @"Greek",
        @15: @"Czech",
        @16: @"Slovak",
        @17: @"Dutch",
        @18: @"Hungarian",
        @19: @"",
        @20: @"Polish",
        @21: @"CH_Tra",
        @22: @"",
        @23: @"",
    };
    
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"NNLocalization" ofType:@"strings"];
    _pairs = [[NSDictionary alloc] initWithContentsOfFile:filePath];
    
    NSArray *_keys = [_pairs.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
        return [obj1 compare:obj2];
    }];

    NSMutableString *_text = [NSMutableString new];
    for (NSString *key in _keys) {
        NSString *current = [NSString stringWithFormat:@"\"%@\" = \"%@\";\n",key,_pairs[key]];
        [_text appendString:current];
    }
    
    NSString *toPath = [self _toPatchPath:@(100).stringValue];
    [_text writeToFile:toPath atomically:true encoding:NSUTF8StringEncoding error:nil];
}

-(IBAction)startParse:(id)sender{
    NSMutableDictionary *allMaps = @{}.mutableCopy;
    
    NSData *data = [[NSData alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"data" ofType:@"xml"]];
    NSError *error;
    GDataXMLDocument *xmlDoc = [[GDataXMLDocument alloc] initWithData:data error:&error];
    if(error){
        NSLog(@"%@",error);
    }
    
    //表单列表
    NSArray *sheets = [xmlDoc.rootElement elementsForName:@"Worksheet"];
    for (NSInteger index = 1; index < sheets.count; index++) { //sheets.count
        GDataXMLElement *theOne = sheets[index];
        NSArray *tables = [theOne elementsForName:@"Table"];
        GDataXMLElement *theTable = tables[0];
        NSArray *rows = [theTable elementsForName:@"Row"];
        for (NSInteger j = 4; j < rows.count; j++) {
            GDataXMLElement *row = rows[j];
            NSArray *cells = [row elementsForName:@"Cell"];
            
            if (cells.count < 3) continue;

            NSString *localKey;
            NSMutableArray *keyList = [NSMutableArray new]; //如果有重复的Key
        
            { //通过这里查找英文的字段所对应的Key.
                GDataXMLElement *english = cells[2];
                GDataXMLElement *data = [[english elementsForName:@"Data"] firstObject];

                for (NSString *key in self.pairs.allKeys) {
                    if ([self.pairs[key] isEqualToString:data.stringValue]) {
                        localKey = key;
                        [keyList addObject:key];
                        [_exits addObject:key];
                    }
                }
            }
            
            if (!localKey) { continue; }
            
            for (NSInteger k = 1; k < 24; k++) { //语言的类型,可自定替换
                if (k == 19) continue;
                if (k == 22) continue;
                if (k == 23) continue;
                
                if (k == 21 &&  [localKey isEqualToString:@"Database_Attribute_Overview"]) {
                    
                }
                
                GDataXMLElement *cell;
                if (k < cells.count) {
                    cell = cells[k];
                } else {
                    cell = cells.lastObject;
                }
            
                GDataXMLElement *data = [[cell elementsForName:@"Data"] firstObject];
                GDataXMLNode *otherNode = [cell attributeForName:@"ss:StyleID"];
                NSString *value = data.stringValue;
                if (!value || value.length == 0) {
                    NSArray *fontList = [cell elementsForName:@"ss:Data"];
                    if (fontList.count != 0) {
                        GDataXMLElement *font = fontList.firstObject;
                        NSArray *_list = [font elementsForName:@"Font"];
                        if (_list.count != 0) {
                            NSMutableString *text = [NSMutableString new];
                            for (GDataXMLElement *_item in _list) {
                                [text appendString:_item.stringValue];
                            }
                            value = text.copy;
                        }
                    }
                }
                if ([self isChinese:cell.stringValue] && (k != 21)) { //如果是中文但不是这一列数据
                    GDataXMLElement *english = cells[2];
                    GDataXMLElement *data = [[english elementsForName:@"Data"] firstObject];
                    value = data.stringValue;
                }
                if (k == 21 && ![self isChinese:cell.stringValue]) { //如果是中文这列数据但不是中文
                    GDataXMLElement *english = cells[2];
                    GDataXMLElement *data = [[english elementsForName:@"Data"] firstObject];
                    value = data.stringValue;
                }
                if ((!value || value.length == 0) && otherNode) {
                    GDataXMLElement *english = cells[2];
                    GDataXMLElement *data = [[english elementsForName:@"Data"] firstObject];
                    value = data.stringValue;
                }
                BOOL number = [self isNum:value];
                if (number) continue;
                
                if (!value || value.length == 0) continue;

                NSMutableDictionary *_dict = allMaps[@(k)];
                if (!_dict) {
                    _dict = [NSMutableDictionary new];
                }
                
                if (keyList.count == 1) {
                    _dict[localKey] = value;
                } else {
                    for (NSString *singleKey in keyList) {
                        _dict[singleKey] = value;
                    }
                }
                
                allMaps[@(k)] = _dict;
            }
        }
    }
    
    //这里打印源文件和目标文件的差异
//    NSLog(@"%@",allMaps);
    NSMutableSet *set = [NSMutableSet setWithArray:self.pairs.allKeys];
    [set minusSet:_exits];
    NSLog(@"%@",set);
//    for (NSString *key in set) {
//        NSLog(@"%@",self.pairs[key]);
//    }
    
    for (NSInteger k = 1; k < 24; k++) {
        if (k == 19) continue;
        if (k == 22) continue;
        if (k == 23) continue;
        NSDictionary *dict = allMaps[@(k)];
        
        NSArray *_keys = [dict.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
            return [obj1 compare:obj2];
        }];
        
        NSMutableString *_text = [NSMutableString new];
        for (NSString *key in _keys) {
            NSString *current = [NSString stringWithFormat:@"\"%@\" = \"%@\";\n",key,dict[key]];
            [_text appendString:current];
        }
        
        NSString *fleeName = self.countryList[@(k)];
        NSString *toPath = [self _toPatchPath:fleeName];
        NSLog(@"%@",toPath);
        [_text writeToFile:toPath atomically:true encoding:NSUTF8StringEncoding error:nil];
    }
}

//进行装配最后的值
-(void)configDataWithArray:(NSArray *)array{
    NSMutableString *showPath = @"".mutableCopy;
    //分成上方的语言名
    NSArray    *languaNames = [[array firstObject] componentsSeparatedByString:@"|"];
    //第一项为各个语言名
    for(NSString *languageName in languaNames){
        NSUInteger index = [languaNames indexOfObject:languageName];
        
        NSMutableString *finalWriteString = [NSMutableString new];
        //后面的从第二行开始为对应的值
        for(int i = 1; i < array.count; i ++){
            NSString *rowString = array[i];
            if([[rowString componentsSeparatedByString:@"|"] count] > languaNames.count){
                //去掉最前面有 =的部分
                NSString *key = [[rowString componentsSeparatedByString:@"|"] firstObject];
                [finalWriteString appendFormat:@"\"%@\" = ",[self removeUnnecesaryString:key]];
                NSString *valueString = [[rowString componentsSeparatedByString:@"|"] objectAtIndex:index + 1];
                [finalWriteString appendFormat:@"\"%@\";\n",[self removeUnnecesaryString:valueString]];
                
            }
        }
        NSData *writeData = [finalWriteString dataUsingEncoding:NSUTF8StringEncoding];
        NSString *writePath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.txt",languageName]];
        [writeData writeToFile:writePath atomically:YES];
        [showPath appendFormat:@"%@\n",writePath];
        [outputText setText:showPath];
    }
}

-(NSString *)removeUnnecesaryString:(NSString *)oriString{
    NSString *first = [oriString stringByReplacingOccurrencesOfString:@"=" withString:@""];
    first = [first stringByReplacingOccurrencesOfString:@";" withString:@""];
    first = [first stringByReplacingOccurrencesOfString:@"\"" withString:@""];
    return [first stringByReplacingOccurrencesOfString:@" " withString:@""];
}

-(IBAction)saveResult:(id)sender{
    if(allDatas.count == 0)
        return;
    [self configDataWithArray:allDatas];
}


#pragma mark - Private
- (BOOL)isNum:(NSString *)checkedNumString {
    checkedNumString = [checkedNumString stringByTrimmingCharactersInSet:[NSCharacterSet decimalDigitCharacterSet]];
    if(checkedNumString.length > 0) {
        return NO;
    }
    return YES;
}

- (BOOL)isChinese:(NSString *)text {
    for(int i=0; i < [text length]; i++){
        int a = [text characterAtIndex:i];
        if( a > 0x4e00 && a < 0x9fff) {
            return true;
        }
    }
    return false;
}

- (NSString *)_toPath:(NSString *)fileName {
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) firstObject];
    NSString *directory = [documentPath stringByAppendingPathComponent:@"Me"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory;
    if (![fileManager fileExistsAtPath:directory isDirectory:&isDirectory]) {
        [fileManager createDirectoryAtPath:directory withIntermediateDirectories:true attributes:nil error:nil];
    }
    
    return [directory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist",fileName]];
}

- (NSString *)_toPatchPath:(NSString *)fileName {
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) firstObject];
    NSString *directory = [documentPath stringByAppendingPathComponent:@"Local"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory;
    if (![fileManager fileExistsAtPath:directory isDirectory:&isDirectory]) {
        [fileManager createDirectoryAtPath:directory withIntermediateDirectories:true attributes:nil error:nil];
    }
    
    return [directory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.txt",fileName]];
}
@end
