#import "ConfigurationManager.h"
#import "CoreConfigurationModel.h"
#import "JsonUtility.h"
#import "NotificationKeys.h"
#import "libkrbn.h"

@interface ConfigurationManager ()

@property libkrbn_configuration_monitor* libkrbn_configuration_monitor;
@property(readwrite) CoreConfigurationModel* coreConfigurationModel;

- (void)loadJsonString:(const char*)currentProfileJsonString;

@end

static void configuration_file_updated_callback(const char* currentProfileJsonString, void* refcon) {
  ConfigurationManager* manager = (__bridge ConfigurationManager*)(refcon);
  [manager loadJsonString:currentProfileJsonString];
  [[NSNotificationCenter defaultCenter] postNotificationName:kConfigurationIsLoaded object:nil];
}

@implementation ConfigurationManager

- (void)setup {
  libkrbn_configuration_monitor* p = NULL;
  if (libkrbn_configuration_monitor_initialize(&p, configuration_file_updated_callback, (__bridge void*)(self))) {
    return;
  }
  self.libkrbn_configuration_monitor = p;
}

- (void)dealloc {
  if (self.libkrbn_configuration_monitor) {
    libkrbn_configuration_monitor* p = self.libkrbn_configuration_monitor;
    libkrbn_configuration_monitor_terminate(&p);
  }
}

- (void)loadJsonString:(const char*)currentProfileJsonString {
  NSDictionary* jsonObject = [JsonUtility loadCString:currentProfileJsonString];
  if (jsonObject) {
    self.coreConfigurationModel = [[CoreConfigurationModel alloc] initWithProfile:jsonObject];
  }
}

- (void)save {
  NSString* filePath = [NSString stringWithUTF8String:libkrbn_get_core_configuration_file_path()];
  NSDictionary* jsonObject = [JsonUtility loadFile:filePath];
  if (!jsonObject) {
    jsonObject = @{};
  }
  NSMutableDictionary* mutableJsonObject = [NSMutableDictionary dictionaryWithDictionary:jsonObject];

  if (!mutableJsonObject[@"profiles"]) {
    mutableJsonObject[@"profiles"] = @[];
  }
  NSMutableArray* mutableProfiles = [NSMutableArray arrayWithArray:mutableJsonObject[@"profiles"]];
  NSInteger __block selectedProfileIndex = -1;
  [mutableProfiles enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL* stop) {
    if (obj[@"selected"] && [obj[@"selected"] boolValue]) {
      selectedProfileIndex = (NSInteger)(index);
      *stop = YES;
    }
  }];
  if (selectedProfileIndex == -1) {
    [mutableProfiles addObject:@{
      @"name" : @"Default profile",
      @"selected" : @(YES),
    }];
    selectedProfileIndex = mutableProfiles.count - 1;
  }

  NSMutableDictionary* mutableProfile = [NSMutableDictionary dictionaryWithDictionary:mutableProfiles[selectedProfileIndex]];
  mutableProfile[@"simple_modifications"] = self.coreConfigurationModel.simpleModificationsDictionary;
  mutableProfile[@"fn_function_keys"] = self.coreConfigurationModel.fnFunctionKeysDictionary;
  mutableProfile[@"virtual_hid_keyboard"] = self.coreConfigurationModel.virtualHIDKeyboardDictionary;
  mutableProfile[@"devices"] = self.coreConfigurationModel.devicesArray;

  mutableProfiles[selectedProfileIndex] = mutableProfile;

  mutableJsonObject[@"profiles"] = mutableProfiles;

  [JsonUtility saveJsonToFile:mutableJsonObject filePath:filePath];
}

@end
