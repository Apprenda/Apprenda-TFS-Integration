using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Activities;
using Microsoft.TeamFoundation.Build.Client;
using Microsoft.TeamFoundation.Build.Workflow.Tracking;
using Microsoft.TeamFoundation.Build.Activities.Extensions;
using Microsoft.TeamFoundation.Build.Activities.Core;
using Microsoft.TeamFoundation.Build.Workflow.Activities;

namespace ApprendaBuildActivity
{
    [BuildActivity(HostEnvironmentOption.All)]
    [BuildExtension(HostEnvironmentOption.All)]
    public sealed class ApprendaCodeActivity : CodeActivity
    {
        private const string RegisterCloud = @" -Command ""& '{0}' RegisterCloud -Url {1} -Alias {2}""";
        private const string ConnectCloud = @" -Command ""& '{0}' ConnectCloud -CloudAlias {1} -User {2} -Password {3} -DevTeamAlias {4} -Remember""";
        private const string NewPackage = @" -Command ""& '{0}' NewPackage -Sln '{1}' -o '{2}' -B {3}""";
        private const string NewVersion = @" -Command ""& '{0}' NewVersion -AppAlias {1} -VersionAlias {2} -Description '{3}' -Stage Sandbox -Package '{4}' -VersionName '{5}'""";
        private const string DisconnectCloud = @" -Command ""& '{0}' DisconnectCloud -Y""";

        /// <summary>
        /// Messages are logged to build log if the user instructed us to log (through the VerboseLogging argument) or if an error occured
        /// </summary>
        private void LogMessage(String message, CodeActivityContext context, bool isError = false)
        {
            bool shouldLog = context.GetValue(this.VerboseLogging);
            if (shouldLog || isError)
            {
                BuildInformationRecord<BuildMessage> record =
                  new BuildInformationRecord<BuildMessage>()
                  {
                      Value = new BuildMessage()
                      {
                          Importance = BuildMessageImportance.High,
                          Message = message,
                      },
                  };

                context.Track(record);
            }
        }

        [RequiredArgument]
        public InArgument<string> ApprendaRootURL { get; set; }

        [RequiredArgument]
        public InArgument<string> CloudAlias { get; set; }

        [RequiredArgument]
        public InArgument<string> AcsPath { get; set; }

        [RequiredArgument]
        public InArgument<string> Username { get; set; }

        [RequiredArgument]
        public InArgument<string> Password { get; set; }

        [RequiredArgument]
        public InArgument<string> DevelopmentTeamAlias { get; set; }

        [RequiredArgument]
        public InArgument<string[]> ProjectToBuild { get; set; }

        [RequiredArgument]
        public InArgument<string> AcsBuildParameters { get; set; }

        [RequiredArgument]
        public InArgument<string> ApplicationAlias { get; set; }

        [RequiredArgument]
        public InArgument<bool> VerboseLogging { get; set; }

        [RequiredArgument]
        public InArgument<string> VersionNamePrefix { get; set; }

        // If your activity returns a value, derive from CodeActivity<TResult>
        // and return the value from the Execute method.
        protected override void Execute(CodeActivityContext context)
        {

            string buildFullName = context.GetExtension<IEnvironmentVariableExtension>().GetEnvironmentVariable<string>(context, WellKnownEnvironmentVariables.BuildNumber);
            string buildNumber = buildFullName.Substring(buildFullName.LastIndexOf("_") + 1).Replace(".", "");
            if (buildNumber.Length > 9)
            {
                // apprenda only allows up to 9 charachers for the version alias and it has to be alphanumeric
                // in this case we are trimming the size to  max 9 characters
                buildNumber = buildNumber.Substring(buildNumber.Length - 9);
            }
            string apprendaRootURL = context.GetValue(this.ApprendaRootURL);
            string cloudAlias = context.GetValue(this.CloudAlias);
            string acsPath = context.GetValue(this.AcsPath);
            string username = context.GetValue(this.Username);
            string password = context.GetValue(this.Password);
            string devTeamAlias = context.GetValue(this.DevelopmentTeamAlias);
            string acsBuildParams = context.GetValue(this.AcsBuildParameters);
            string[] projectToBuild = context.GetValue(this.ProjectToBuild);
            string appAlias = context.GetValue(this.ApplicationAlias);
            string versionNamePrefix = context.GetValue(this.VersionNamePrefix);
            string packageName = projectToBuild[0].Substring(0, projectToBuild[0].LastIndexOf(".")).Substring(projectToBuild[0].LastIndexOf("/") + 1) + ".zip";

            // add the Fully Qualified path including the zip extension to the name of the solution for the Apprenda package
            // we will drop this ZIP file on the root folder of the build destination directory
            string zipPackageFullPath = context.GetExtension<IEnvironmentVariableExtension>().GetEnvironmentVariable<string>(
                context, WellKnownEnvironmentVariables.DropLocation) + @"\" + packageName;

            // get the path to the solution file, after eliminating the TFS root path of $/<tfs name>/
            string tfsCodeDirectory = context.GetExtension<IEnvironmentVariableExtension>().GetEnvironmentVariable<string>(
                context, WellKnownEnvironmentVariables.SourcesDirectory);
            string tfsRelativePath = projectToBuild[0].Substring(projectToBuild[0].IndexOf("/", 2)).Replace("/", @"\");
            string tfsSolutionFilePath = tfsCodeDirectory + tfsRelativePath;

            // populate the ACS path now
            acsPath = (tfsCodeDirectory.EndsWith(@"\") ? tfsCodeDirectory : tfsCodeDirectory + @"\") + (acsPath.StartsWith(@"\") ? acsPath.Substring(1) : acsPath);

            if (projectToBuild.Count() > 1)
            {
                context.TrackBuildWarning(string.Format("Apprenda: You entered more than 1 Solution in the Build Definition. The Apprenda Code Activity will only utilize the first one entered - {0}", projectToBuild[0]));
            }

            LogMessage("Apprenda: The Apprenda TFS Build Activity will now execute", context);
            LogMessage("---Code Activity Parameters---", context);
            LogMessage("ApprendaRootURL: " + apprendaRootURL, context);
            LogMessage("CloudAlias: " + cloudAlias, context);
            LogMessage("AcsPath: " + acsPath, context);
            LogMessage("Username: " + username, context);
            LogMessage("Password: ********", context);
            LogMessage("DevelopmentTeamAlias: " + devTeamAlias, context);
            LogMessage("AcsBuildParameters: " + acsBuildParams, context);
            LogMessage("ProjectToBuild: " + projectToBuild[0], context);
            LogMessage("ApplicationAlias: " + appAlias, context);

            string acsRegisterCloudCmd = string.Format(RegisterCloud, acsPath, apprendaRootURL, cloudAlias);
            string acsConnectCloudCmd = string.Format(ConnectCloud, acsPath, cloudAlias, username, password, devTeamAlias);
            string acsNewPackageCmd = string.Format(NewPackage, acsPath, tfsSolutionFilePath, zipPackageFullPath, acsBuildParams);
            string acsNewVersionCmd = string.Format(NewVersion, acsPath, appAlias, buildNumber, "Created from Apprenda TFS Activity", zipPackageFullPath, buildFullName);
            string acsDisconnectCloudCmd = string.Format(DisconnectCloud, acsPath);

            LogMessage("---Code Activity Constructed Commands---", context);
            LogMessage("ACS command 1: " + acsRegisterCloudCmd, context);
            LogMessage("ACS command 2: " + acsConnectCloudCmd.Replace(password, "********"), context);
            LogMessage("ACS command 3: " + acsNewPackageCmd, context);
            LogMessage("ACS command 4: " + acsNewVersionCmd, context);
            LogMessage("ACS command 5: " + acsDisconnectCloudCmd, context);

            var buildDetail = context.GetExtension<IBuildDetail>();
            buildDetail.RefreshAllDetails();
            if (!buildDetail.BuildFinished)
            {
                LogMessage("Apprenda: Build is not finished yet! - " + buildDetail.Status.ToString(), context);
            }

            LogMessage("---Execute Apprenda ACS Utility Commands---", context);
            this.RunCommand(acsRegisterCloudCmd, context);
            this.RunCommand(acsConnectCloudCmd, context);
            this.RunCommand(acsNewPackageCmd, context);
            this.RunCommand(acsNewVersionCmd, context);
            this.RunCommand(acsDisconnectCloudCmd, context);
        }

        private void RunCommand(string command, CodeActivityContext context)
        {
            LogMessage("@@@@@@@@@@@@", context);
            LogMessage("Apprenda: Executing command <<" + command + ">> as " + Environment.UserDomainName + @"\" + Environment.UserName, context);
            using (System.Diagnostics.Process process = new System.Diagnostics.Process())
            {
                process.StartInfo.FileName = Environment.ExpandEnvironmentVariables(@"PowerShell.exe");
                process.StartInfo.Arguments = " " + command;
                process.StartInfo.UseShellExecute = false;
                process.StartInfo.ErrorDialog = false;
                process.StartInfo.WindowStyle = System.Diagnostics.ProcessWindowStyle.Hidden;
                process.StartInfo.RedirectStandardOutput = true;
                process.StartInfo.RedirectStandardError = true;
                process.Start();
                
                string msTestOutput = process.StandardOutput.ReadToEnd();
                string msErrOutput = process.StandardError.ReadToEnd();
                LogMessage("Standard Output: " + msTestOutput, context);
                LogMessage("Error output: " + msErrOutput, context);
                    
                process.WaitForExit();

                if (process.ExitCode != 0)
                {
                    bool verboseLogging = context.GetValue(this.VerboseLogging);
                    // verboselogging would have printed out the process output already
                    if (!verboseLogging)
                    {
                        LogMessage("Apprenda: Executing command <<" + command + ">> as " + Environment.UserDomainName + @"\" + Environment.UserName, context);
                        LogMessage("Standard Output: " + msTestOutput, context, true);
                        LogMessage("Error output: " + msErrOutput, context, true);
                    }
                    context.TrackBuildError("Apprenda: Fail the Apprenda custom build activity because ACS failed with exit code " + process.ExitCode);
                }            
            }
            LogMessage("@@@@@@@@@@@@", context);
        }
    }
}

