classdef CITasks < TaskList
    % testCI - Used by Jenkins plugin to exercise utilities of the DO
    % Project.
    %
    % Copyright 2019 The MathWorks, Inc.
    
    %% Revision History
    %======================================================================
    %   Geck        Name        Date        Description
    %----------------------------------------------------------------------
    %	N/A         MDM         11/11/19	Initial version
    %   N/A         RSN
    %======================================================================
    
    %% TODO
    % 1. Should report scripts use load_system vs open_system? Would make
    % them quicker but doesn't affect test point.
    %
    % 2. genReqReport and genSDD should have optional argument to not open
    % report after it is created.
    
    properties
        Project;    % Handle to the DO Project.
        StartDir;   % Directory in which this test point is located.
        ProjectDir; % Directory in which the project is located.
        ModelNames; % Names of models in the DO_03_Design directory.
    end
    
    properties
        TaskOrder = ["task_GenReqReport"
                     "task_GenSDD"
                     "task_VerifyModel2Reqs"
                     "task_CheckModelStds"
                     "task_DetectDesignErrs"
                     "task_GenSrcCode"
                     "task_VerifySrcCode2Mode"
                     "task_CheckCodeStds"
                     "task_ProveCodeQuality"
                     "task_VerifyObjCode2Reqs"
                     "task_GenLowLevelTests"
                     "task_VerifyObjCode2LowLevelTests"
                     "task_MergeCodeCoverage"];
    end
    
    methods %TestClassSetup
        function setupOnce(this)
            % LOAD PROJECT
            this.StartDir = fileparts(mfilename('fullpath'));
            cd(this.StartDir);
            addpath(this.StartDir);
            this.ProjectDir = fullfile(this.StartDir, 'DODemo');
            this.Project = matlab.project.loadProject(this.ProjectDir);
            
            %GET MODEL NAMES
            designDir = fullfile(this.ProjectDir, 'DO_03_Design');
            dirList = dir(designDir);
            
            % Ignore common, sample_model, and names that are not a folder.
            ignoreDir = arrayfun(@(x) (x.isdir == 0) || strcmpi(x.name, 'sample_model') || strcmpi(x.name, 'common') || strcmpi(x.name, '.') || strcmpi(x.name, '..'), dirList);
            dirList = dirList(~ignoreDir);
            this.ModelNames = arrayfun(@(x) (x.name), dirList, 'UniformOutput', false);
        end
        
        function setupEachTask(this)
            this.deleteMcrCache();
        end
        
        function cleanupEachTask(this)
            this.restoreDir();
            this.killReaders();
        end
        
        function cleanupOnce(this)
            this.closeProject();
        end
    end
    
    methods %EachTaskSetup
        function deleteMcrCache(~)
            % Depending on installed/cofigured MATLAB components, the
            % MATLAB Complier Cache can cause errors with polyspace.
            % The issue appears to be related to the cache being created
            % via interactive session and then reused from a jenkins ci
            % session or vice version.
            % Delete the mcr cache to avoid this problem.
            
            %RETURN EARLY TEMPORARILY
            return; 
            
            cacheDir = fullfile(tempdir,getenv('username')); %#ok<UNRCH>
            if exist(cacheDir,'dir')
%                 rmdir(cacheDir,'s');
            end
        end
    end
    
    methods %EachTaskCleanup
        function restoreDir(this)
            cd(this.StartDir);
        end
        function killReaders(~)
            % Most of these test cases open a generated word or pdf
            % document.  We need to close these programs otherwise the file
            % will be locked the next time a test tries to write the file.
            
            % Close all PDF documents opened via MATLAB, Acrobat or MS Edge.
            if ispc
                system('taskkill /F /IM MATLABWindow.exe');
                system('taskkill /F /IM AcroRd32.exe');
                system('taskkill /F /IM MicrosoftPdfReader.exe');
                system('taskkill /F /IM MicrosoftEdgeCP.exe');
            end
            
            % Close all HTML documents opened via MATLAB.
            [~, h] = web();
            h.close();
        end
    end
    
    methods %CleanupOnce
        function closeProject(this)
            % close project and generate reports
            
            % Generate a summary report in XML format that can be processed by the
            % Jenkins Sumary Display Plugin. See the following linke for details
            % https://wiki.jenkins.io/display/JENKINS/Summary+Display+Plugin
            %
            r = JenkinsReport;
            r.createModelStdsTable({});

            this.Project.close();
        end
    end
    
    methods %Tasks
        function task_GenReqReport(this)
            % This test case checks if both Requirement Reports generated
            % from System Requirements and High-Level Software Requirements
            % are successfully created by "genReqReport".
            
            % NOTE: Requirement Reports are .docx files prior to R2020a.
            % They are .pdf files starting in R2020a.
            
            if verLessThan('matlab', '9.8')
                fileExt = 'docx';
            else
                fileExt = 'pdf';
            end
            
            % Test generation of Requirement Report from SR.slreq.
            genReqReport('SR');
            fileCreated = dir(fullfile(this.ProjectDir, 'DO_02_Requirements', 'specification', 'documents', ['SR_ReqReport.', fileExt]));
            
            assert(~isempty(fileCreated), ['Requirement Report not created: SR_ReqReport.', fileExt, '.']);
            
            % Test generation of Requirement Report from HLR.slreq.
            genReqReport('HLR');
            fileCreated = dir(fullfile(this.ProjectDir, 'DO_02_Requirements', 'specification', 'documents', ['HLR_ReqReport.', fileExt]));
            assert(~isempty(fileCreated), ['Requirement Report not created: HLR_ReqReport.', fileExt, '.']);
            
            % Because "genReqReport" opens the generated reports,
            % subsequent runs of this test point will fail unless we close
            % the reports.
            if verLessThan('matlab', '9.8')
                % Close all Word documents.
                if ispc
                    system('taskkill /F /IM winword.exe');
                end
            end
        end
        
        function task_GenSDD(this)
            % This test case checks if SDD Reports generated from models
            % are successfully created by "genSDD".
            
            % Test generation of SDD Reports from models in the project.
            for i=1:numel(this.ModelNames)
                genSDD(this.ModelNames{i});
                fileCreated = dir(fullfile(this.ProjectDir, 'DO_03_Design', this.ModelNames{i}, 'specification', 'documents', [this.ModelNames{i}, '_SDD.pdf']));
                assert(~isempty(fileCreated), ['SDD Report not created: ', this.ModelNames{i}, '_SDD.pdf.']);
            end
        end
        
        function task_VerifyModel2Reqs(this)
            % This test case checks if Simulink Test and Model Coverage
            % Reports generated from models are successfully created by
            % "verifyModel2Reqs".
            
            % Test generation of Simulink Test and Model Coverage Reports
            % (for HLR Simulation Tests) from models in the project.
            for i=1:numel(this.ModelNames)
                if exist(fullfile(this.ProjectDir, 'DO_03_Design', this.ModelNames{i}, 'test_cases', 'HLR', [this.ModelNames{i}, '_REQ_Based_Test.mldatx']), 'file')
                    verifyModel2Reqs(this.ModelNames{i});
                    fileCreated = dir(fullfile(this.ProjectDir, 'DO_03_Design', this.ModelNames{i}, 'verification_results', 'simulation_results', 'HLR', [this.ModelNames{i}, '_REQ_Based_Test_Report.pdf']));
                    assert(~isempty(fileCreated),['Simulation Test Report not created: ', this.ModelNames{i}, '_REQ_Based_Test_Report.pdf.']);
                    fileCreated = dir(fullfile(this.ProjectDir, 'DO_03_Design', this.ModelNames{i}, 'verification_results', 'model_coverages', 'HLR', [this.ModelNames{i}, '_REQ_Based_Model_Coverage_Report.html']));
                    assert(~isempty(fileCreated), ['Model Coverage Report not created: ', this.ModelNames{i}, '_REQ_Based_Model_Coverage_Report.html.']);
                end
            end
            
            % Close all HTML documents opened via MATLAB.
%             [~, h] = web();
%             h.close();
        end
        
        function task_CheckModelStds(this)
            % This test case checks if Model Advisor Reports generated from
            % models are successfully created by "checkModelStds".
            
            % Remove cache if it exists.
            if exist(fullfile(this.ProjectDir, 'work', 'cache', 'slprj', 'modeladvisor'), 'dir')
                rmdir(fullfile(this.ProjectDir, 'work', 'cache', 'slprj', 'modeladvisor'), 's');
            end
            
                
                % Test generation of Model Advisor Reports from models in the
                % project.
                for i=1:numel(this.ModelNames)
                    if strcmpi(this.ModelNames{i}, 'flight_control')
                        checkModelStds(this.ModelNames{i});
                    else
                        checkModelStds(this.ModelNames{i}, 'TreatAsMdlRef');
                    end
                    % Jenkins throws an error when trying to generate a report
                    % in PDF format.  A timeout error is generated when opening
                    % the temp word document, resulting in no PDF file.  Until
                    % we determine root cause, generate word doc.
                    if ~isempty(getenv('JENKINS_HOME'))
                        ReportFormat = 'docx';
                    else
                        ReportFormat = 'pdf';
                    end
                    fileCreated = dir(fullfile(this.ProjectDir, 'DO_03_Design', this.ModelNames{i}, 'verification_results', 'design_standard_checks', [this.ModelNames{i}, '_SMS_Conformance_Report.', ReportFormat]));
                    assert(~isempty(fileCreated), ['Model Advisor Report not created: ', this.ModelNames{i}, '_SMS_Conformance_Report.', ReportFormat]);
                end
        end
        
        function task_DetectDesignErrs(this)
            % This test case checks if Design Error Detection Reports
            % generated from models are successfully created by
            % "detectDesignErrs".
            
            % NOTE: Simulink Design Verifier analysis for detecting design
            % errors and dead logic must be performed separately prior to
            % R2019b. They can be analyzed together starting in R2019b.
            if verLessThan('matlab', '9.7')
                reportDir = 'design_error';
            else
                reportDir = '';
            end
            
            % Test generation of Design Error Detection Reports from models
            % in the project.
            for i=1:numel(this.ModelNames)
                detectDesignErrs(this.ModelNames{i});
                fileCreated = dir(fullfile(this.ProjectDir, 'DO_03_Design', this.ModelNames{i}, 'verification_results', 'design_error_detections', reportDir, [this.ModelNames{i}, '_Design_Error_Detection_Report.pdf']));
                assert(~isempty(fileCreated), ['Design Error Detection Report not created: ', this.ModelNames{i}, '_Design_Error_Detection_Report.pdf.']);
            end
        end
        
        function task_GenSrcCode(this)
            % This test case checks if Code Generation Reports generated
            % from models are successfully created by "genSrcCode".
            
            % Test generation of Code Generation Reports from models in the
            % project.
            for i=1:numel(this.ModelNames)
                if strcmpi(this.ModelNames{i}, 'flight_control')
                    genSrcCode(this.ModelNames{i});
                    fileCreated = dir(fullfile(this.ProjectDir, 'DO_04_Code', 'specification', [this.ModelNames{i}, '_ert_rtw'], 'html', [this.ModelNames{i}, '_codegen_rpt.html']));
                else
                    genSrcCode(this.ModelNames{i}, 'TreatAsMdlRef');
                    fileCreated = dir(fullfile(this.ProjectDir, 'DO_04_Code', 'specification', 'slprj', 'ert', this.ModelNames{i}, 'html', [this.ModelNames{i}, '_codegen_rpt.html']));
                end
                assert(~isempty(fileCreated), ['Code Generation Report not created: ', this.ModelNames{i}, '_codegen_rpt.html.']);
            end
        end
        
        function task_VerifySrcCode2Mode(this)
            % This test case checks if Code Inspection Reports generated
            % from models are successfully created by "verifySrcCode2Mode".
            
            % Test generation of Code Inspection Reports from models in the
            % project.
            for i=1:numel(this.ModelNames)
                if strcmpi(this.ModelNames{i}, 'flight_control')
                    verifySrcCode2Model(this.ModelNames{i});
                else
                    verifySrcCode2Model(this.ModelNames{i}, 'TreatAsMdlRef');
                end
                fileCreated = dir(fullfile(this.ProjectDir, 'DO_04_Code', 'verification_results', 'code_reviews', this.ModelNames{i}, [this.ModelNames{i}, '_summaryReport.html']));
                assert(~isempty(fileCreated), ['Code Inspection Report not created: ', this.ModelNames{i}, '_summaryReport.html.']);
            end
            
            % Close all HTML documents opened via MATLAB.
            [~, h] = web();
            h.close();
        end
        
        function task_CheckCodeStds(this)
            % This test case checks if Bug Finder Reports generated from
            % models are successfully created by "checkCodeStds".
            
            % Test generation of Bug Finder Reports from models in the
            % project.
            for i=1:numel(this.ModelNames)
                if strcmpi(this.ModelNames{i}, 'flight_control')
                    checkCodeStds(this.ModelNames{i});
                else
                    checkCodeStds(this.ModelNames{i}, 'TreatAsMdlRef');
                end
                fileCreated = dir(fullfile(this.ProjectDir, 'DO_04_Code', 'verification_results', 'code_standard_checks', this.ModelNames{i}, [this.ModelNames{i}, '_SCS_Conformance_Report.pdf']));
                assert(~isempty(fileCreated), ['Bug Finder Report not created: ', this.ModelNames{i}, '_SCS_Conformance_Report.pdf.']);
            end
        end
        
        function task_ProveCodeQuality(this)
            % This test case checks if Code Prover Reports generated from
            % models are successfully created by "proveCodeQuality".
            
            % Test generation of Code Prover Reports from models in the
            % project.
            for i=1:numel(this.ModelNames)
                if strcmpi(this.ModelNames{i}, 'flight_control')
                    proveCodeQuality(this.ModelNames{i}, 'IncludeAllChildMdls');
                else
                    proveCodeQuality(this.ModelNames{i}, 'TreatAsMdlRef', 'IncludeAllChildMdls');
                end
                fileCreated = dir(fullfile(this.ProjectDir, 'DO_04_Code', 'verification_results', 'code_proving', this.ModelNames{i}, [this.ModelNames{i}, '_Code_Prover_Report.pdf']));
                assert(~isempty(fileCreated), ['Code Prover Report not created: ', this.ModelNames{i}, '_Code_Prover_Report.pdf.']);
            end
        end
        
        function task_VerifyObjCode2Reqs(this)
            % This test case checks if Simulink Test and Code Coverage
            % Reports generated from models are successfully created by
            % "verifyObjCode2Reqs".
            
            % Test generation of Simulink Test and Code Coverage Reports
            % (for HLR EOC Tests) from models in the project.
            for i=1:numel(this.ModelNames)
                if exist(fullfile(this.ProjectDir, 'DO_03_Design', this.ModelNames{i}, 'test_cases', 'HLR', [this.ModelNames{i}, '_REQ_Based_Test.mldatx']), 'file')
                    verifyObjCode2Reqs(this.ModelNames{i}, 'SIL');
                    fileCreated = dir(fullfile(this.ProjectDir, 'DO_04_Code', 'verification_results', 'eoc_test_results', this.ModelNames{i}, 'host', 'HLR', 'instrumented', [this.ModelNames{i}, '_INSTR_SIL_REQ_Based_Test_Report.pdf']));
                    this.verifyEqual(isempty(fileCreated), false, ['EOC Test Report not created: ', this.ModelNames{i}, '_INSTR_SIL_REQ_Based_Test_Report.pdf.']);
                    fileCreated = dir(fullfile(this.ProjectDir, 'DO_04_Code', 'verification_results', 'code_coverages', this.ModelNames{i}, 'host', 'HLR', [this.ModelNames{i}, '_REQ_Based_Code_Coverage_Report.html']));
                    assert(~isempty(fileCreated), ['Code Coverage Report not created: ', this.ModelNames{i}, '_REQ_Based_Code_Coverage_Report.html.']);
                end
            end
        end
        
        function task_GenLowLevelTests(this)
            % This test case checks if Test Generation Reports generated
            % from models are successfully created by "genLowLevelTests".
            
            % Test generation of Test Generation Reports from models in the
            % project.
            for i=1:numel(this.ModelNames)
                if exist(fullfile(this.ProjectDir, 'DO_03_Design', this.ModelNames{i}, 'verification_results', 'model_coverages', 'HLR', [this.ModelNames{i}, '_REQ_Based_Model_Coverage.cvt']), 'file')
                    genLowLevelTests(this.ModelNames{i});
                    fileCreated = dir(fullfile(this.ProjectDir, 'DO_03_Design', this.ModelNames{i}, 'test_cases', 'LLR', [this.ModelNames{i}, '_Test_Generation_Report.pdf']));
                    assert(~isempty(fileCreated), ['Test Generation Report not created: ', this.ModelNames{i}, '_Test_Generation_Report.pdf.']);
                end
            end
        end
        
        function task_VerifyObjCode2LowLevelTests(this)
            % This test case checks if Simulink Test and Code Coverage
            % Reports generated from models are successfully created by
            % "verifyObjCode2LowLevelTests".
            
            % Test generation of Simulink Test and Code Coverage Reports
            % (for LLR EOC Tests) from models in the project.
            for i=1:numel(this.ModelNames)
                if exist(fullfile(this.ProjectDir, 'DO_03_Design', this.ModelNames{i}, 'test_cases', 'LLR', [this.ModelNames{i}, '_SLDV_Based_Test.mldatx']), 'file')
                    verifyObjCode2LowLevelTests(this.ModelNames{i}, 'SIL');
                    fileCreated = dir(fullfile(this.ProjectDir, 'DO_04_Code', 'verification_results', 'eoc_test_results', this.ModelNames{i}, 'host', 'LLR', 'instrumented', [this.ModelNames{i}, '_INSTR_SIL_SLDV_Based_Test_Report.pdf']));
                    assert(~isempty(fileCreated), ['EOC Test Report not created: ', this.ModelNames{i}, '_INSTR_SIL_SLDV_Based_Test_Report.pdf.']);
                    fileCreated = dir(fullfile(this.ProjectDir, 'DO_04_Code', 'verification_results', 'code_coverages', this.ModelNames{i}, 'host', 'LLR', [this.ModelNames{i}, '_SLDV_Based_Code_Coverage_Report.html']));
                    assert(~isempty(fileCreated), ['Code Coverage Report not created: ', this.ModelNames{i}, '_SLDV_Based_Code_Coverage_Report.html.']);
                end
            end
        end
        
        function task_MergeCodeCoverage(this)
            % This test case checks if Cumulative Code Coverage Reports
            % generated from models are successfully created by
            % "mergeCodeCoverage".
            
            % Test generation of Cumulative Code Coverage Reports from
            % models in the project.
            for i=1:numel(this.ModelNames)
                if exist(fullfile(this.ProjectDir, 'DO_04_Code', 'verification_results', 'eoc_test_results', this.ModelNames{i}, 'host', 'HLR', 'instrumented', [this.ModelNames{i}, '_INSTR_SIL_REQ_Based_Test_Results.mldatx']), 'file') ...
                        && exist(fullfile(this.ProjectDir, 'DO_04_Code', 'verification_results', 'eoc_test_results', this.ModelNames{i}, 'host', 'LLR', 'instrumented', [this.ModelNames{i}, '_INSTR_SIL_SLDV_Based_Test_Results.mldatx']), 'file')
                    mergeCodeCoverage(this.ModelNames{i}, 'SIL');
                    fileCreated = dir(fullfile(this.ProjectDir, 'DO_04_Code', 'verification_results', 'code_coverages', this.ModelNames{i}, 'host', [this.ModelNames{i}, '_Merged_Code_Coverage_Report.html']));
                    assert(~isempty(fileCreated), ['Cumulative Code Coverage Report not created: ', this.ModelNames{i}, '_Merged_Code_Coverage_Report.html.']);
                end
            end
            
            % Close all HTML documents opened via MATLAB.
            [~, h] = web();
            h.close();
        end
    end
end
