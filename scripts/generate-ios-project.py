#!/usr/bin/env python3
"""Dependency-free, deterministic Xcode project generator. Run on Windows, Linux or macOS."""
from pathlib import Path
import hashlib, plistlib
root=Path(__file__).resolve().parents[1]/'ios'
def uid(s):return hashlib.sha256(s.encode()).hexdigest()[:24].upper()
def q(s):return '"'+str(s).replace('\\','\\\\').replace('"','\\"')+'"'
objects={}
def obj(key,body):objects[uid(key)]=body;return uid(key)
def group(key,children,path=None):return obj(key,'isa = PBXGroup; children = ('+','.join(children)+'); sourceTree = "<group>";'+(' path = '+q(path)+';' if path else ''))
apps=sorted((root/'Meteor').glob('*.swift'));tests=sorted((root/'Tests').glob('*.swift'))
refs={};builds={}
for f in apps+tests:
 k=f.relative_to(root).as_posix();refs[k]=obj('file'+k,'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = '+q(f.name)+'; sourceTree = "<group>";');builds[k]=obj('build'+k,'isa = PBXBuildFile; fileRef = '+refs[k]+';')
privacy=obj('privacyref','isa = PBXFileReference; lastKnownFileType = text.xml; path = PrivacyInfo.xcprivacy; sourceTree = "<group>";')
privacybuild=obj('privacybuild','isa = PBXBuildFile; fileRef = '+privacy+';')
assets=obj('assetsref','isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>";')
assetsbuild=obj('assetsbuild','isa = PBXBuildFile; fileRef = '+assets+';')
appProduct=obj('appproduct','isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Meteor.app; sourceTree = BUILT_PRODUCTS_DIR;')
testProduct=obj('testproduct','isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = MeteorTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
sourcegroup=group('sources',[refs[f.relative_to(root).as_posix()] for f in apps]+[privacy,assets],'Meteor')
testgroup=group('tests',[refs[f.relative_to(root).as_posix()] for f in tests],'Tests')
products=group('products',[appProduct,testProduct]);main=group('main',[sourcegroup,testgroup,products])
def phase(key,isa,files):return obj(key,'isa = '+isa+'; buildActionMask = 2147483647; files = ('+','.join(files)+'); runOnlyForDeploymentPostprocessing = 0;')
appSources=phase('appsources','PBXSourcesBuildPhase',[builds[f.relative_to(root).as_posix()] for f in apps]);testSources=phase('testsources','PBXSourcesBuildPhase',[builds[f.relative_to(root).as_posix()] for f in tests]);appResources=phase('appresources','PBXResourcesBuildPhase',[privacybuild,assetsbuild]);testResources=phase('testresources','PBXResourcesBuildPhase',[]);appFrameworks=phase('appframeworks','PBXFrameworksBuildPhase',[]);testFrameworks=phase('testframeworks','PBXFrameworksBuildPhase',[])
def configlist(key,base):
 configs=[]
 for mode in ['Debug','Release']:
  settings=base|({'SWIFT_OPTIMIZATION_LEVEL':'-Onone','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG','DEBUG_INFORMATION_FORMAT':'dwarf'} if mode=='Debug' else {'SWIFT_OPTIMIZATION_LEVEL':'-O','DEBUG_INFORMATION_FORMAT':'dwarf-with-dsym'})
  configs.append(obj(key+mode,'isa = XCBuildConfiguration; name = '+mode+'; buildSettings = {'+' '.join(q(k)+' = '+q(v)+';' for k,v in settings.items())+'};'))
 return obj(key+'list','isa = XCConfigurationList; buildConfigurations = ('+','.join(configs)+'); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
projectconfigs=configlist('project',{'SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SWIFT_VERSION':'5.0','CLANG_ENABLE_MODULES':'YES','ENABLE_TESTABILITY':'YES','SWIFT_STRICT_CONCURRENCY':'minimal'})
appconfigs=configlist('app',{'PRODUCT_NAME':'Meteor','PRODUCT_BUNDLE_IDENTIFIER':'hu.csaladitv.meteor.ios','INFOPLIST_FILE':'Meteor/Info.plist','TARGETED_DEVICE_FAMILY':'1,2','CODE_SIGN_STYLE':'Automatic','CURRENT_PROJECT_VERSION':'2','MARKETING_VERSION':'0.1.1','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','SKIP_INSTALL':'NO','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','SUPPORTS_MACCATALYST':'NO'})
testconfigs=configlist('test',{'PRODUCT_NAME':'MeteorTests','PRODUCT_BUNDLE_IDENTIFIER':'hu.csaladitv.meteor.ios.tests','GENERATE_INFOPLIST_FILE':'YES','TARGETED_DEVICE_FAMILY':'1,2','TEST_HOST':'$(BUILT_PRODUCTS_DIR)/Meteor.app/Meteor','BUNDLE_LOADER':'$(TEST_HOST)','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks @loader_path/Frameworks'})
proxy=obj('proxy','isa = PBXContainerItemProxy; containerPortal = '+uid('project')+'; proxyType = 1; remoteGlobalIDString = '+uid('app')+'; remoteInfo = Meteor;')
dep=obj('dependency','isa = PBXTargetDependency; target = '+uid('app')+'; targetProxy = '+proxy+';')
obj('app','isa = PBXNativeTarget; name = Meteor; productName = Meteor; productType = "com.apple.product-type.application"; productReference = '+appProduct+'; buildConfigurationList = '+appconfigs+'; buildPhases = ('+','.join([appSources,appFrameworks,appResources])+'); buildRules = (); dependencies = ();')
obj('test','isa = PBXNativeTarget; name = MeteorTests; productName = MeteorTests; productType = "com.apple.product-type.bundle.unit-test"; productReference = '+testProduct+'; buildConfigurationList = '+testconfigs+'; buildPhases = ('+','.join([testSources,testFrameworks,testResources])+'); buildRules = (); dependencies = ('+dep+');')
obj('project','isa = PBXProject; attributes = { LastUpgradeCheck = 1600; TargetAttributes = {'+uid('test')+' = { TestTargetID = '+uid('app')+'; }; }; }; buildConfigurationList = '+projectconfigs+'; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,sk,hu,Base); mainGroup = '+main+'; productRefGroup = '+products+'; projectDirPath = ""; projectRoot = ""; targets = ('+uid('app')+','+uid('test')+');')
project=root/'Meteor.xcodeproj';project.mkdir(exist_ok=True)
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+''.join(k+' = { '+v+' };\n' for k,v in objects.items())+'}; rootObject = '+uid('project')+'; }\n')
schemes=project/'xcshareddata/xcschemes';schemes.mkdir(parents=True,exist_ok=True)
def ref(key,name,product):return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid(key)}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:Meteor.xcodeproj"/>'
(schemes/'Meteor.xcscheme').write_text('''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">'''+ref('app','Meteor','Meteor.app')+'''</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">'''+ref('test','MeteorTests','MeteorTests.xctest')+'''</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">'''+ref('app','Meteor','Meteor.app')+'''</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">'''+ref('app','Meteor','Meteor.app')+'''</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>
''')
info={'CFBundleDisplayName':'Meteor','CFBundleName':'Meteor','CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)','CFBundleExecutable':'$(EXECUTABLE_NAME)','CFBundlePackageType':'APPL','CFBundleShortVersionString':'$(MARKETING_VERSION)','CFBundleVersion':'$(CURRENT_PROJECT_VERSION)','LSRequiresIPhoneOS':True,'UILaunchScreen':{},'UIBackgroundModes':['audio'],'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],'UISupportedInterfaceOrientations~ipad':['UIInterfaceOrientationPortrait','UIInterfaceOrientationPortraitUpsideDown','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],'ITSAppUsesNonExemptEncryption':False}
(root/'Meteor/Info.plist').write_bytes(plistlib.dumps(info))
collected=[{
 'NSPrivacyCollectedDataType':kind,
 'NSPrivacyCollectedDataTypeLinked':True,
 'NSPrivacyCollectedDataTypeTracking':False,
 'NSPrivacyCollectedDataTypePurposes':['NSPrivacyCollectedDataTypePurposeAppFunctionality']
} for kind in ['NSPrivacyCollectedDataTypeDeviceID','NSPrivacyCollectedDataTypeOtherDiagnosticData']]
(root/'Meteor/PrivacyInfo.xcprivacy').write_bytes(plistlib.dumps({'NSPrivacyTracking':False,'NSPrivacyTrackingDomains':[],'NSPrivacyCollectedDataTypes':collected,'NSPrivacyAccessedAPITypes':[{'NSPrivacyAccessedAPIType':'NSPrivacyAccessedAPICategoryUserDefaults','NSPrivacyAccessedAPITypeReasons':['CA92.1']}]}))
print(project)
