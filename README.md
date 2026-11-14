# compiling mustangproject to native CLI

This lets you use ZUGFeRD validations directly on windows x64 / linux command line, without java dependency.

 the cli is expected to be able to do everything you could do with the jar.

as of 2026-11-14, the 

linux jar can validate 163   files, the cli does 163  

windows jar validates 163    files, the cli does 163



##linux - prerequisites

Image: Debian 13 HVM, 40GB local EBS

sudo apt update
sudo apt-get  install screen build-essential zlib1g-dev git maven unzip zip

curl -s "https://get.sdkman.io" | bash

source $HOME/.sdkman/bin/sdkman-init.sh
sdk install java 25.5.5.0+3-graalce


git clone https://github.com/kralo/mustangproject-cli-native-win.git
cd mustangpro*
git remote add upstream https://github.com/ZUGFeRD/mustangproject.git
git fetch upstream

curl -o ./validator/src/main/java/org/verapdf/pdfa/validation/validators/JavaScriptEvaluator.java https://raw.githubusercontent.com/veraPDF/veraPDF-library/refs/tags/v1.30.3/core/src/main/java/org/verapdf/pdfa/validation/validators/JavaScriptEvaluator.java

## linux  - building


mvn versions:set -DnewVersion=2.26.1-42127fa3

bash runCliNativeCompile.sh


## Windows - prerequisites


AWS Image: windows 2019 base

Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

choco install git maven firefox notepadplusplus
choco install graalvm --version=25.0.2

Initialize-Disk -Number 1 -PartitionStyle GPT

New-Partition -DiskNumber 1 -UseMaximumSize -DriveLetter D |
    Format-Volume -FileSystem NTFS -NewFileSystemLabel "BuildTools" -Confirm:$false
    
    
    
git clone https://github.com/kralo/mustangproject-cli-native-win.git

cd mustangprojec*

mvn -Dmaven.repo.local=D:\MavenCache\repository -Dmaven.test.skip=true -Dcheckstyle.skip clean install

( from the x64 tools Command Prompt)
native-image --add-modules=java.xml -H:+UnlockExperimentalVMOptions -H:IncludeResources=".*\.(xsd|xml|xsl|xslt)$" -H:+ReportExceptionStackTraces -H:ConfigurationFileDirectories=../../mynative-image -H:+AddAllCharsets   --no-fallback -Ob -H:Name=Mustang-CLI -jar Mustang-CLi-xxx
    
call "D:\vsinstall\Common7\Tools\VsDevCmd.bat" -arch=amd64 

( and therein )
"C:\Program Files\Git\bin\bash.exe" --login -i



## Windows - compile

mvn versions:set -DnewVersion=2.26.1-42127fa3

bash runCliNativeCompile.sh




( the windows run takes around 1600 seconds on c3.xlarge )



## CAVEATS

rhin pdf overwrite was needed because:
   
   Unsupported GraalVM feature:
com.oracle.svm.core.jdk.UnsupportedFeatureError: Classes cannot be defined at runtime by default when using ahead-of-time Native Image compilation. Tried to define class:

    org.mozilla.javascript.gen.unnamed_script_98

To make this work, you have the following options:
  1) Modify or reconfigure your application (or a third-party library) so that it does not generate classes at runtime or load them via non-built-in class loaders.
  2) If the classes must be generated, try to generate them at build time in a static initializer of a dedicated class. The generated java.lang.Class objects should be stored in static fields and the dedicated class initialized by passing '--initialize-at-build-time=<class_name>' as the build argument.
  3) If none of the above is applicable, use the tracing agent to run this application and collect predefined classes with 'java -agentlib:native-image-agent=config-output-dir=<config-dir>,experimental-class-define-support <application-arguments>'. Note that this is an experimental feature and that it does not guarantee success. Furthermore, the resulting classes can contain entries from the classpath that should be manually filtered out to reduce image size. The agent should be used only in cases where modifying the source of the project is not possible.

	at org.graalvm.nativeimage.shared/com.oracle.svm.shared.util.VMError.unsupportedFeature(VMError.java:123)
	at org.graalvm.nativeimage.builder/com.oracle.svm.core.hub.RuntimeClassLoading.throwNoBytecodeClasses(RuntimeClassLoading.java:197)
	at org.graalvm.nativeimage.builder/com.oracle.svm.core.hub.RuntimeClassLoading.defineClass(RuntimeClassLoading.java:178)
	at java.base@25.0.4.1.1/java.lang.ClassLoader.defineClass(ClassLoader.java:321)
	at org.mozilla.javascript.DefiningClassLoader.defineClass(DefiningClassLoader.java:26)
	at org.mozilla.javascript.optimizer.Codegen.defineClass(Codegen.java:141)
	at org.mozilla.javascript.optimizer.Codegen.createScriptObject(Codegen.java:102)
	at org.mozilla.javascript.Context.compileImpl(Context.java:2483)
	at org.mozilla.javascript.Context.compileString(Context.java:1404)
	at org.mozilla.javascript.Context.compileString(Context.java:1392)
	at org.mozilla.javascript.Context.evaluateString(Context.java:1170)
	at org.verapdf.pdfa.validation.validators.JavaScriptEvaluator.evaluateString(JavaScriptEvaluator.java:52)
	at org.verapdf.pdfa.validation.validators.BaseValidator.initializeAllVariables(BaseValidator.java:232)
	at org.verapdf.pdfa.validation.validators.BaseValidator.initialise(BaseValidator.java:222)
	at org.verapdf.pdfa.validation.validators.BaseValidator.validate(BaseValidator.java:174)
	at org.verapdf.pdfa.validation.validators.BaseValidator.validateAll(BaseValidator.java:149)
	at org.verapdf.processor.ProcessorImpl.validate(ProcessorImpl.java:241)
	at org.verapdf.processor.ProcessorImpl.process(ProcessorImpl.java:173)
	at org.mustangproject.validator.PDFValidator.validate(PDFValidator.java:124)
	at org.mustangproject.validator.ZUGFeRDValidator.internalValidate(ZUGFeRDValidator.java:161)
	at org.mustangproject.validator.ZUGFeRDValidator.validate(ZUGFeRDValidator.java:270)
	at org.mustangproject.commandline.ValidatorFileWalker.visitFile(ValidatorFileWalker.java:74)
	at org.mustangproject.commandline.ValidatorFileWalker.visitFile(ValidatorFileWalker.java:26)
	at java.base@25.0.4.1.1/java.nio.file.Files.walkFileTree(Files.java:2543)
	at java.base@25.0.4.1.1/java.nio.file.Files.walkFileTree(Files.java:2609)
	at org.mustangproject.commandline.Main.performValidateExpect(Main.java:557)
	at org.mustangproject.commandline.Main.main(Main.java:490)
[main] INFO org.mustangproject.commandline.ValidatorFileWalker - 
   
