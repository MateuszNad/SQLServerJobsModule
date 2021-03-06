#
# Module manifest for module 'SQLServerJobsModule'
#
# Generated by: Mateusz Nadobnik
#
# Generated on: 13/06/2017
#
@{
	
	# Script module or binary module file associated with this manifest.
	RootModule = 'SQLServerJobsModule.psm1'
	
	# Version number of this module.
	ModuleVersion = '1.0.0.1'
	
	# ID used to uniquely identify this module
	GUID = '20a82b86-b22b-4763-869f-8b0e2284d3fb'
	
	# Author of this module
	Author = 'Nadobnik Mateusz'
	
	# Company or vendor of this module
	CompanyName = 'mnadobnik.pl'
	
	# Copyright statement for this module
	Copyright = 'mnadobnik.pl'
	
	# Description of the functionality provided by this module
	Description = 'The script allows you to generate a report about Jobs from several servers. Allows you to specify a time window for the report. Allows you get details about connections in packages IS.'
	
	# Minimum version of the Windows PowerShell engine required by this module
	PowerShellVersion = '4.0'
	
	# Name of the Windows PowerShell host required by this module
	PowerShellHostName = ''
	
	# Minimum version of the Windows PowerShell host required by this module
	PowerShellHostVersion = ''
	
	# Minimum version of the .NET Framework required by this module
	DotNetFrameworkVersion = ''
	
	# Minimum version of the common language runtime (CLR) required by this module
	CLRVersion = ''
	
	# Processor architecture (None, X86, Amd64, IA64) required by this module
	ProcessorArchitecture = ''
	
	# Modules that must be imported into the global environment prior to importing this module
	RequiredModules = @()
	
	# Assemblies that must be loaded prior to importing this module
	RequiredAssemblies = @()
	
	# Script files () that are run in the caller's environment prior to importing this module
	ScriptsToProcess = @()
	
	# Type files (xml) to be loaded when importing this module
	TypesToProcess = @()
	
	# Format files (xml) to be loaded when importing this module
	FormatsToProcess = @()
	
	# Modules to import as nested modules of the module specified in ModuleToProcess
	NestedModules = @()
	
	# Functions to export from this module
	FunctionsToExport = @(
        'Get-SQLServerJobs',
        'Show-SQLServerJobsReport'
	)
	
	# Cmdlets to export from this module
	CmdletsToExport = '*'
	
	# Variables to export from this module
	VariablesToExport = '*'
	
	# Aliases to export from this module
	AliasesToExport = ''
	
	# List of all modules packaged with this module
	ModuleList = @()
	
	# List of all files packaged with this module
	FileList = ''
	
	PrivateData = @{
    PSData = @{
        # The primary categorization of this module (from the TechNet Gallery tech tree).
        Category = "Databases"

        # Keyword tags to help users find this module via navigations and search.
        Tags = @('sqlserver','sql','dba','databases','jobs','reports')

        # The web address of an icon which can be used in galleries to represent this module
        IconUri = "http://mnadobnik.pl/logo.png"

        # The web address of this module's project or support homepage.
        ProjectUri = "http://mnadobnik.pl"

        # The web address of this module's license. Points to a page that's embeddable and linkable.
        LicenseUri = ""

        # Release notes for this particular version of the module
        # ReleaseNotes = False

        # If true, the LicenseUrl points to an end-user license (not just a source license) which requires the user agreement before use.
        # RequireLicenseAcceptance = ""

        # Indicates this is a pre-release/testing version of the module.
        IsPrerelease = 'True'
		} 
	}
}