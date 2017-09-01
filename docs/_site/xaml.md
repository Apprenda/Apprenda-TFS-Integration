# Apprenda Xaml Build Steps
## Considerations:
1. The current version of TFS requires you to build a new Build Definition per Application, as the alias for the app is encompassed as a Build Definition Parameter.
1. At the moment, the publish-as credentials are stored in Plain-Text within the Build Definition. This will get updated to use encryption through certs.
1. Apprenda expects a Published version of the app alias to exist in the environment for the TFS workflow to be able to create a new Sandboxed version under.

## Installation steps
### ACS.exe And Xaml Build Steps
1. Create a branch within your TFS project called apprendatfs
1. Open Visual Studio and Check Out the newly created branch
1. Create a new folder called ApprendaCustomActivities within your project's branch.
    1. The DLLs from the Xaml Build directory at [GitHub](https://github.com/apprenda/Apprenda-TFS-Integration/tree/master/2013)
    1. `ACS.exe` from the [Apprenda SDK](https://docs.apprenda.com/downloads) for your target Apprenda Cloud Platform
1. Verify that you can see the changes under Team Explorer in Visual Studio
1. Commit and sync the changes.
1. Publish the branch.
1. Open TFS Team Explorer
1. Open Build | Manage Build.