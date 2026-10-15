#!/usr/bin/env python3
"""Regenerate the checked-in Xcode project using only Python's standard library."""
from pathlib import Path
import hashlib, json
import xml.etree.ElementTree as ET
root = Path(__file__).resolve().parent.parent
objects = {}
def ident(key): return hashlib.sha256(key.encode()).hexdigest()[:24].upper()
def put(key, isa, **fields):
    ref = ident(key); objects[ref] = dict(isa=isa, **fields); return ref
class Ref(str): pass
def ref(value): return Ref(value)
def file(path, kind): return ref(put('file:'+path, 'PBXFileReference', lastKnownFileType=kind, path=path, sourceTree='<group>'))
def phase(key, isa, files, **kw): return ref(put(key, isa, buildActionMask=2147483647, files=files, runOnlyForDeploymentPostprocessing=0, **kw))
def build(key, f, **kw): return ref(put(key,'PBXBuildFile',fileRef=f,**kw))
modules=['AtlasCore','AtlasReceiver','AtlasThemes','AtlasPlayback']
names=modules+['e2Atlas']
targets={n:ref(ident('target:'+n)) for n in names}
products={n:ref(put('product:'+n,'PBXFileReference',explicitFileType='wrapper.application' if n=='e2Atlas' else 'wrapper.framework',includeInIndex=0,path='e2Atlas Dev.app' if n=='e2Atlas' else n+'.framework',sourceTree='BUILT_PRODUCTS_DIR')) for n in names}
vlc=file('Build/Dependencies/VLCKit - binary package/VLCKit.xcframework/macos-arm64_x86_64/VLCKit.framework','wrapper.framework')
allfiles=[vlc]; depmap={'AtlasCore':[],'AtlasReceiver':['AtlasCore'],'AtlasThemes':[],'AtlasPlayback':['AtlasCore'],'e2Atlas':modules}
base={'SDKROOT':'macosx','MACOSX_DEPLOYMENT_TARGET':'26.0','ARCHS':'arm64','SWIFT_VERSION':'6.0','SWIFT_STRICT_CONCURRENCY':'complete','CLANG_ENABLE_MODULES':'YES','CODE_SIGN_IDENTITY':'-','CODE_SIGN_STYLE':'Manual','DEVELOPMENT_TEAM':'','ENABLE_USER_SCRIPT_SANDBOXING':'NO','E2ATLAS_APP_NAME':'e2Atlas Dev','E2ATLAS_BUNDLE_IDENTIFIER':'io.github.schrotty74.e2atlas.dev','E2ATLAS_BUILD_CHANNEL':'dev','MARKETING_VERSION':'0.1.0','CURRENT_PROJECT_VERSION':'1','E2ATLAS_RELEASE_VERSION':'0.1.0-dev','OTHER_SWIFT_FLAGS':['$(inherited)','-debug-prefix-map','"$(SRCROOT)=."','-file-prefix-map','"$(SRCROOT)=."'],'FRAMEWORK_SEARCH_PATHS':['$(inherited)','"$(SRCROOT)/Build/Dependencies/VLCKit - binary package/VLCKit.xcframework/macos-arm64_x86_64"']}
def configs(key, extra):
    cs=[]
    for c in ['Debug','Release']:
        opts=dict(extra,SWIFT_OPTIMIZATION_LEVEL='-Onone' if c=='Debug' else '-O',DEBUG_INFORMATION_FORMAT='dwarf' if c=='Debug' else 'dwarf-with-dsym',SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG' if c=='Debug' else '')
        cs.append(ref(put(key+c,'XCBuildConfiguration',buildSettings=opts,name=c)))
    return ref(put(key+'list','XCConfigurationList',buildConfigurations=cs,defaultConfigurationIsVisible=0,defaultConfigurationName='Debug'))
for n in names:
    srcs=[]
    for p in sorted((root/'Sources'/n).rglob('*.swift')):
        f=file(p.relative_to(root).as_posix(),'sourcecode.swift'); allfiles.append(f); srcs.append(build(n+str(p.relative_to(root)),f))
    link=[build(n+'link'+d,products[d]) for d in depmap[n]]
    if n in ['AtlasPlayback','e2Atlas']: link.append(build(n+'linkvlc',vlc))
    phases=[phase(n+'sources','PBXSourcesBuildPhase',srcs),phase(n+'frameworks','PBXFrameworksBuildPhase',link)]
    resources=[]
    if n=='e2Atlas':
        for path,kind in [('Sources/AtlasThemes/Resources/Themes','folder'),('Resources/ThirdPartyNotices.txt','text'),('LICENSE','text'),('Resources/VLCKit-LICENSE.txt','text'),('Resources/AppIcon.icon','folder.iconcomposer.icon')]:
            f=file(path,kind); allfiles.append(f); resources.append(build('resource'+path,f))
        phases.append(phase(n+'embed','PBXCopyFilesBuildPhase',[build('embedvlc',vlc,settings={'ATTRIBUTES':['CodeSignOnCopy','RemoveHeadersOnCopy']})],dstPath='',dstSubfolderSpec=10,name='Embed VLCKit'))
    if n=='AtlasPlayback':
        phases.insert(0,ref(put('fetch','PBXShellScriptBuildPhase',buildActionMask=2147483647,files=[],inputPaths=[],outputPaths=[],runOnlyForDeploymentPostprocessing=0,shellPath='/bin/bash',shellScript='"$SRCROOT/Scripts/fetch-vlckit.sh"\n',alwaysOutOfDate=1,name='Fetch verified VLCKit')))
    phases.append(phase(n+'resources','PBXResourcesBuildPhase',resources))
    deps=[]
    for d in depmap[n]:
        proxy=ref(put(n+'proxy'+d,'PBXContainerItemProxy',containerPortal=ref(ident('project')),proxyType=1,remoteGlobalIDString=targets[d],remoteInfo=d))
        deps.append(ref(put(n+'dep'+d,'PBXTargetDependency',target=targets[d],targetProxy=proxy)))
    opts={'PRODUCT_NAME':n,'PRODUCT_MODULE_NAME':n,'PRODUCT_BUNDLE_IDENTIFIER':'io.github.schrotty74.e2atlas.'+n.lower(),'GENERATE_INFOPLIST_FILE':'YES','DEFINES_MODULE':'YES','MACH_O_TYPE':'staticlib','SKIP_INSTALL':'YES','SWIFT_INSTALL_OBJC_HEADER':'NO','ENABLE_TESTABILITY':'YES'}
    if n=='e2Atlas': opts={'PRODUCT_NAME':'$(E2ATLAS_APP_NAME)','PRODUCT_MODULE_NAME':'e2Atlas','PRODUCT_BUNDLE_IDENTIFIER':'$(E2ATLAS_BUNDLE_IDENTIFIER)','INFOPLIST_FILE':'Resources/Info.plist','GENERATE_INFOPLIST_FILE':'NO','LD_RUNPATH_SEARCH_PATHS':['$(inherited)','@executable_path/../Frameworks'],'ENABLE_HARDENED_RUNTIME':'YES','COMBINE_HIDPI_IMAGES':'YES','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon'}
    put('target:'+n,'PBXNativeTarget',buildConfigurationList=configs(n,opts),buildPhases=phases,buildRules=[],dependencies=deps,name=n,productName=n,productReference=products[n],productType='com.apple.product-type.application' if n=='e2Atlas' else 'com.apple.product-type.framework')
# Xcode uses the same Swift Testing sources as SwiftPM, with a bundled VLC runtime.
testname='e2AtlasTests'
testtarget=ref(ident('target:'+testname))
testproduct=ref(put('product:'+testname,'PBXFileReference',explicitFileType='wrapper.cfbundle',includeInIndex=0,path=testname+'.xctest',sourceTree='BUILT_PRODUCTS_DIR'))
products[testname]=testproduct
testfiles=[]
for p in sorted((root/'Tests').rglob('*.swift')):
    f=file(p.relative_to(root).as_posix(),'sourcecode.swift'); allfiles.append(f); testfiles.append(build('test'+str(p.relative_to(root)),f))
testdeps=[]
for d in modules:
    proxy=ref(put('testproxy'+d,'PBXContainerItemProxy',containerPortal=ref(ident('project')),proxyType=1,remoteGlobalIDString=targets[d],remoteInfo=d))
    testdeps.append(ref(put('testdep'+d,'PBXTargetDependency',target=targets[d],targetProxy=proxy)))
put('target:'+testname,'PBXNativeTarget',buildConfigurationList=configs(testname,{'PRODUCT_NAME':testname,'PRODUCT_MODULE_NAME':testname,'PRODUCT_BUNDLE_IDENTIFIER':'io.github.schrotty74.e2atlas.tests','GENERATE_INFOPLIST_FILE':'YES','LD_RUNPATH_SEARCH_PATHS':['$(inherited)','@loader_path/../Frameworks','@loader_path/Frameworks'],'ENABLE_TESTABILITY':'YES'}),buildPhases=[phase('testsources','PBXSourcesBuildPhase',testfiles),phase('testlinks','PBXFrameworksBuildPhase',[build('testlink'+d,products[d]) for d in modules]+[build('testlinkvlc',vlc)]),phase('testembed','PBXCopyFilesBuildPhase',[build('testembedvlc',vlc,settings={'ATTRIBUTES':['CodeSignOnCopy','RemoveHeadersOnCopy']})],dstPath='',dstSubfolderSpec=10,name='Embed test VLC runtime')],buildRules=[],dependencies=testdeps,name=testname,productName=testname,productReference=testproduct,productType='com.apple.product-type.bundle.unit-test')
targets[testname]=testtarget
productgroup=ref(put('products','PBXGroup',children=list(products.values()),name='Products',sourceTree='<group>'))
main=ref(put('main','PBXGroup',children=allfiles+[productgroup],sourceTree='<group>'))
put('project','PBXProject',attributes={'BuildIndependentTargetsInParallel':'YES','LastUpgradeCheck':'2700'},buildConfigurationList=configs('project',base),compatibilityVersion='Xcode 14.0',developmentRegion='de',hasScannedForEncodings=0,knownRegions=['de','en','Base'],mainGroup=main,productRefGroup=productgroup,projectDirPath='',projectRoot='',targets=list(targets.values()))
def encode(x,depth=0):
    if isinstance(x,Ref): return str(x)
    if isinstance(x,dict): return '{\n'+''.join('\t'*(depth+1)+json.dumps(str(k))+' = '+encode(v,depth+1)+';\n' for k,v in x.items())+'\t'*depth+'}'
    if isinstance(x,list): return '('+', '.join(encode(v,depth) for v in x)+')'
    if isinstance(x,int): return str(x)
    return json.dumps(x)
proj=root/'e2Atlas.xcodeproj'; proj.mkdir(exist_ok=True)
(proj/'project.pbxproj').write_text('// !$*UTF8*$!\n'+encode({'archiveVersion':1,'classes':{},'objectVersion':56,'objects':objects,'rootObject':ref(ident('project'))})+'\n')
scheme=ET.Element('Scheme',LastUpgradeVersion='2700',version='1.3')
def bref(parent): ET.SubElement(parent,'BuildableReference',BuildableIdentifier='primary',BlueprintIdentifier=targets['e2Atlas'],BuildableName='e2Atlas Dev.app',BlueprintName='e2Atlas',ReferencedContainer='container:e2Atlas.xcodeproj')
ba=ET.SubElement(scheme,'BuildAction',parallelizeBuildables='YES',buildImplicitDependencies='YES'); entries=ET.SubElement(ba,'BuildActionEntries'); entry=ET.SubElement(entries,'BuildActionEntry',buildForTesting='YES',buildForRunning='YES',buildForProfiling='YES',buildForArchiving='YES',buildForAnalyzing='YES'); bref(entry)
testaction=ET.SubElement(scheme,'TestAction',buildConfiguration='Debug',selectedDebuggerIdentifier='Xcode.DebuggerFoundation.Debugger.LLDB',selectedLauncherIdentifier='Xcode.IDEFoundation.Launcher.LLDB',shouldUseLaunchSchemeArgsEnv='YES')
testables=ET.SubElement(testaction,'Testables')
testable=ET.SubElement(testables,'TestableReference',skipped='NO')
ET.SubElement(testable,'BuildableReference',BuildableIdentifier='primary',BlueprintIdentifier=testtarget,BuildableName='e2AtlasTests.xctest',BlueprintName=testname,ReferencedContainer='container:e2Atlas.xcodeproj')
la=ET.SubElement(scheme,'LaunchAction',buildConfiguration='Debug',selectedDebuggerIdentifier='Xcode.DebuggerFoundation.Debugger.LLDB',selectedLauncherIdentifier='Xcode.IDEFoundation.Launcher.LLDB',launchStyle='0',useCustomWorkingDirectory='NO',ignoresPersistentStateOnLaunch='NO',debugDocumentVersioning='YES',debugServiceExtension='internal',allowLocationSimulation='YES'); bref(ET.SubElement(la,'BuildableProductRunnable',runnableDebuggingMode='0'))
ET.SubElement(scheme,'AnalyzeAction',buildConfiguration='Debug'); ET.SubElement(scheme,'ArchiveAction',buildConfiguration='Release',revealArchiveInOrganizer='YES')
path=proj/'xcshareddata'/'xcschemes'; path.mkdir(parents=True,exist_ok=True); ET.indent(scheme); ET.ElementTree(scheme).write(path/'e2Atlas.xcscheme',encoding='UTF-8',xml_declaration=True)
print('Generated e2Atlas.xcodeproj')
