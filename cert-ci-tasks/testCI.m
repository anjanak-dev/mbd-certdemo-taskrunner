classdef testCI < matlab.unittest.TestCase
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
    
    properties (TestParameter)
    end
    
    methods(TestClassSetup)
        function loadProject(testCase)
            testCase.StartDir = fileparts(mfilename('fullpath'));
            cd(testCase.StartDir);
            addpath(testCase.StartDir);
            testCase.ProjectDir = fullfile(testCase.StartDir, 'DODemo');
            testCase.Project = matlab.project.loadProject(testCase.ProjectDir);
        end
        
        function getModelNames(testCase)
            designDir = fullfile(testCase.ProjectDir, 'DO_03_Design');
            dirList = dir(designDir);
            
            % Ignore common, sample_model, and names that are not a folder.
            ignoreDir = arrayfun(@(x) (x.isdir == 0) || strcmpi(x.name, 'sample_model') || strcmpi(x.name, 'common') || strcmpi(x.name, '.') || strcmpi(x.name, '..'), dirList);
            dirList = dirList(~ignoreDir);
            testCase.ModelNames = arrayfun(@(x) (x.name), dirList, 'UniformOutput', false);
        end
    end
    methods(TestMethodSetup)
        function deleteMcrCache(testCase)
            % Depending on installed/cofigured MATLAB components, the
            % MATLAB Complier Cache can cause errors with polyspace.
            % The issue appears to be related to the cache being created
            % via interactive session and then reused from a jenkins ci
            % session or vice version.
            % Delete the mcr cache to avoid this problem.
            
            cacheDir = fullfile(tempdir,getenv('username'));
            if exist(cacheDir,'dir')
                rmdir(cacheDir,'s');
            end
        end
    end
    
    methods(TestMethodTeardown)
        function restoreDir(testCase)
            cd(testCase.StartDir);
        end
        function killReaders(testCase)
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
    
    methods(TestClassTeardown)
        function closeProject(testCase)
            % close project and generate reports
            
            % Generate a summary report in XML format that can be processed by the
            % Jenkins Sumary Display Plugin. See the following linke for details
            % https://wiki.jenkins.io/display/JENKINS/Summary+Display+Plugin
            %
            r = JenkinsReport;
            r.createModelStdsTable({});

            testCase.Project.close();
        end
        
    end
    methods(Test)
        function testGenReqReport(testCase)
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
            fileCreated = dir(fullfile(testCase.ProjectDir, 'DO_02_Requirements', 'specification', 'documents', ['SR_ReqReport.', fileExt]));
            testCase.verifyEqual(isempty(fileCreated), false, ['Requirement Report not created: SR_ReqReport.', fileExt, '.']);
            
            % Test generation of Requirement Report from HLR.slreq.
            genReqReport('HLR');
            fileCreated = dir(fullfile(testCase.ProjectDir, 'DO_02_Requirements', 'specification', 'documents', ['HLR_ReqReport.', fileExt]));
            testCase.verifyEqual(isempty(fileCreated), false, ['Requirement Report not created: HLR_ReqReport.', fileExt, '.']);
            
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
        
        function testGenSDD(testCase)
            % This test case checks if SDD Reports generated from models
            % are successfully created by "genSDD".
            
            % Test generation of SDD Reports from models in the project.
            for i=1:numel(testCase.ModelNames)
                genSDD(testCase.ModelNames{i});
                fileCreated = dir(fullfile(testCase.ProjectDir, 'DO_03_Design', testCase.ModelNames{i}, 'specification', 'documents', [testCase.ModelNames{i}, '_SDD.pdf']));
                testCase.verifyEqual(isempty(fileCreated), false, ['SDD Report not created: ', testCase.ModelNames{i}, '_SDD.pdf.']);
            end
        end
        
        function testVerifyModel2Reqs(testCase)
            % This test case checks if Simulink Test and Model Coverage
            % Reports generated from models are successfully created by
            % "verifyModel2Reqs".
            
            % Test generation of Simulink Test and Model Coverage Reports
            % (for HLR Simulation Tests) from models in the project.
            for i=1:numel(testCase.ModelNames)
                if exist(fullfile(testCase.ProjectDir, 'DO_03_Design', testCase.ModelNames{i}, 'test_cases', 'HLR', [testCase.ModelNames{i}, '_REQ_Based_Test.mldatx']), 'file')
                    verifyModel2Reqs(testCase.ModelNames{i});
                    fileCreated = dir(fullfile(testCase.ProjectDir, 'DO_03_Design', testCase.ModelNames{i}, 'verification_results', 'simulation_results', 'HLR', [testCase.ModelNames{i}, '_REQ_Based_Test_Report.pdf']));
                    testCase.verifyEqual(isempty(fileCreated), false, ['Simulation Test Report not created: ', testCase.ModelNames{i}, '_REQ_Based_Test_Report.pdf.']);
                    fileCreated = dir(fullfile(testCase.ProjectDir, 'DO_03_Design', testCase.ModelNames{i}, 'verification_results', 'model_coverages', 'HLR', [testCase.ModelNames{i}, '_REQ_Based_Model_Coverage_Report.html']));
                    testCase.verifyEqual(isempty(fileCreated), false, ['Model Coverage Report not created: ', testCase.ModelNames{i}, '_REQ_Based_Model_Coverage_Report.html.']);
                end
            end
            
            % Close all HTML documents opened via MATLAB.
            [~, h] = web();
            h.close();
        end
        
        function testCheckModelStds(testCase)
            % This test case checks if Model Advisor Reports generated from
            % models are successfully created by "checkModelStds".
            
            % Remove cache if it exists.
            if exist(fullfile(testCase.ProjectDir, 'work', 'cache', 'slprj', 'modeladvisor'), 'dir')
                rmdir(fullfile(testCase.ProjectDir, 'work', 'cache', 'slprj', 'modeladvisor'), 's');
            end
            
                
                % Test generation of Model Advisor Reports from models in the
                % project.
                for i=1:numel(testCase.ModelNames)
                    if strcmpi(testCase.ModelNames{i}, 'flight_control')
                        checkModelStds(testCase.ModelNames{i});
                    else
                        checkModelStds(testCase.ModelNames{i}, 'TreatAsMdlRef');
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
                    fileCreated = dir(fullfile(testCase.ProjectDir, 'DO_03_Design', testCase.ModelNames{i}, 'verification_results', 'design_standard_checks', [testCase.ModelNames{i}, '_SMS_Conformance_Report.', ReportFormat]));
                    testCase.verifyEqual(isempty(fileCreated), false, ['Model Advisor Report not created: ', testCase.ModelNames{i}, '_SMS_Conformance_Report.', ReportFormat]);
                end
        end
        
        function testDetectDesignErrs(testCase)
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
            for i=1:numel(testCase.ModelNames)
                detectDesignErrs(testCase.ModelNames{i});
                fileCreated = dir(fullfile(testCase.ProjectDir, 'DO_03_Design', testCase.ModelNames{i}, 'verification_results', 'design_error_detections', reportDir, [testCase.ModelNames{i}, '_Design_Error_Detection_Report.pdf']));
                testCase.verifyEqual(isempty(fileCreated), false, ['Design Error Detection Report not created: ', testCase.ModelNames{i}, '_Design_Error_Detection_Report.pdf.']);
            end
        end
        
        function testGenSrcCode(testCase)
            % This test case checks if Code Generation Reports generated
            % from models are successfully created by "genSrcCode".
            
            % Test generation of Code Generation Reports from models in the
            % project.
            for i=1:numel(testCase.ModelNames)
                if strcmpi(testCase.ModelNames{i}, 'flight_control')
                    genSrcCode(testCase.ModelNames{i});
                    fileCreated = dir(fullfile(testCase.ProjectDir, 'DO_04_Code', 'specification', [testCase.ModelNames{i}, '_ert_rtw'], 'html', [testCase.ModelNames{i}, '_codegen_rpt.html']));
                else
                    genSrcCode(testCase.ModelNames{i}, 'TreatAsMdlRef');
                    fileCreated = dir(fullfile(testCase.ProjectDir, 'DO_04_Code', 'specification', 'slprj', 'ert', testCase.ModelNames{i}, 'html', [testCase.ModelNames{i}, '_codegen_rpt.html']));
                end
                testCase.verifyEqual(isempty(fileCreated), false, ['Code Generation Report not created: ', testCase.ModelNames{i}, '_codegen_rpt.html.']);
            end
        end
        
        function testVerifySrcCode2Mode(testCase)
            % This test case checks if Code Inspection Reports generated
            % from models are successfully created by "verifySrcCode2Mode".
            
            % Test generation of Code Inspection Reports from models in the
            % project.
            for i=1:numel(testCase.ModelNames)
                if strcmpi(testCase.ModelNames{i}, 'flight_control')
                    verifySrcCode2Model(testCase.ModelNames{i});
                else
                    verifySrcCode2Model(testCase.ModelNames{i}, 'TreatAsMdlRef');
                end
                fileCreated = dir(fullfile(testCase.ProjectDir, 'DO_04_Code', 'verification_results', 'code_reviews', testCase.ModelNames{i}, [testCase.ModelNames{i}, '_summaryReport.html']));
                testCase.verifyEqual(isempty(fileCreated), false, ['Code Inspection Report not created: ', testCase.ModelNames{i}, '_summaryReport.html.']);
            end
            
            % Close all HTML documents opened via MATLAB.
            [~, h] = web();
            h.close();
        end
        
        function testCheckCodeStds(testCase)
            % This test case checks if Bug Finder Reports generated from
            % models are successfully created by "checkCodeStds".
            
            % Test generation of Bug Finder Reports from models in the
            % project.
            for i=1:numel(testCase.ModelNames)
                if strcmpi(testCase.ModelNames{i}, 'flight_control')
                    checkCodeStds(testCase.ModelNames{i});
                else
                    checkCodeStds(testCase.ModelNames{i}, 'TreatAsMdlRef');
                end
                fileCreated = dir(fullfile(testCase.ProjectDir, 'DO_04_Code', 'verification_results', 'code_standard_checks', testCase.ModelNames{i}, [testCase.ModelNames{i}, '_SCS_Conformance_Report.pdf']));
                testCase.verifyEqual(isempty(fileCreated), false, ['Bug Finder Report not created: ', testCase.ModelNames{i}, '_SCS_Conformance_Report.pdf.']);
            end
        end
        
        function testProveCodeQuality(testCase)
            % This test case checks if Code Prover Reports generated from
            % models are successfully created by "proveCodeQuality".
            
            % Test generation of Code Prover Reports from models in the
            % project.
            for i=1:numel(testCase.ModelNames)
                if strcmpi(testCase.ModelNames{i}, 'flight_control')
                    proveCodeQuality(testCase.ModelNames{i}, 'IncludeAllChildMdls');
                else
                    proveCodeQuality(testCase.ModelNames{i}, 'TreatAsMdlRef', 'IncludeAllChildMdls');
                end
                fileCreated = dir(fullfile(testCase.ProjectDir, 'DO_04_Code', 'verification_results', 'code_proving', testCase.ModelNames{i}, [testCase.ModelNames{i}, '_Code_Prover_Report.pdf']));
                testCase.verifyEqual(isempty(fileCreated), false, ['Code Prover Report not created: ', testCase.ModelNames{i}, '_Code_Prover_Report.pdf.']);
            end
        end
        
        function testVerifyObjCode2Reqs(testCase)
            % This test case checks if Simulink Test and Code Coverage
            % Reports generated from models are successfully created by
            % "verifyObjCode2Reqs".
            
            % Test generation of Simulink Test and Code Coverage Reports
            % (for HLR EOC Tests) from models in the project.
            for i=1:numel(testCase.ModelNames)
                if exist(fullfile(testCase.ProjectDir, 'DO_03_Design', testCase.ModelNames{i}, 'test_cases', 'HLR', [testCase.ModelNames{i}, '_REQ_Based_Test.mldatx']), 'file')
                    verifyObjCode2Reqs(testCase.ModelNames{i}, 'SIL');
                    fileCreated = dir(fullfile(testCase.ProjectDir, 'DO_04_Code', 'verification_results', 'eoc_test_results', testCase.ModelNames{i}, 'host', 'HLR', 'instrumented', [testCase.ModelNames{i}, '_INSTR_SIL_REQ_Based_Test_Report.pdf']));
                    testCase.verifyEqual(isempty(fileCreated), false, ['EOC Test Report not created: ', testCase.ModelNames{i}, '_INSTR_SIL_REQ_Based_Test_Report.pdf.']);
                    fileCreated = dir(fullfile(testCase.ProjectDir, 'DO_04_Code', 'verification_results', 'code_coverages', testCase.ModelNames{i}, 'host', 'HLR', [testCase.ModelNames{i}, '_REQ_Based_Code_Coverage_Report.html']));
                    testCase.verifyEqual(isempty(fileCreated), false, ['Code Coverage Report not created: ', testCase.ModelNames{i}, '_REQ_Based_Code_Coverage_Report.html.']);
                end
            end
        end
        
        function testGenLowLevelTests(testCase)
            % This test case checks if Test Generation Reports generated
            % from models are successfully created by "genLowLevelTests".
            
            % Test generation of Test Generation Reports from models in the
            % project.
            for i=1:numel(testCase.ModelNames)
                if exist(fullfile(testCase.ProjectDir, 'DO_03_Design', testCase.ModelNames{i}, 'verification_results', 'model_coverages', 'HLR', [testCase.ModelNames{i}, '_REQ_Based_Model_Coverage.cvt']), 'file')
                    genLowLevelTests(testCase.ModelNames{i});
                    fileCreated = dir(fullfile(testCase.ProjectDir, 'DO_03_Design', testCase.ModelNames{i}, 'test_cases', 'LLR', [testCase.ModelNames{i}, '_Test_Generation_Report.pdf']));
                    testCase.verifyEqual(isempty(fileCreated), false, ['Test Generation Report not created: ', testCase.ModelNames{i}, '_Test_Generation_Report.pdf.']);
                end
            end
        end
        
        function testVerifyObjCode2LowLevelTests(testCase)
            % This test case checks if Simulink Test and Code Coverage
            % Reports generated from models are successfully created by
            % "verifyObjCode2LowLevelTests".
            
            % Test generation of Simulink Test and Code Coverage Reports
            % (for LLR EOC Tests) from models in the project.
            for i=1:numel(testCase.ModelNames)
                if exist(fullfile(testCase.ProjectDir, 'DO_03_Design', testCase.ModelNames{i}, 'test_cases', 'LLR', [testCase.ModelNames{i}, '_SLDV_Based_Test.mldatx']), 'file')
                    verifyObjCode2LowLevelTests(testCase.ModelNames{i}, 'SIL');
                    fileCreated = dir(fullfile(testCase.ProjectDir, 'DO_04_Code', 'verification_results', 'eoc_test_results', testCase.ModelNames{i}, 'host', 'LLR', 'instrumented', [testCase.ModelNames{i}, '_INSTR_SIL_SLDV_Based_Test_Report.pdf']));
                    testCase.verifyEqual(isempty(fileCreated), false, ['EOC Test Report not created: ', testCase.ModelNames{i}, '_INSTR_SIL_SLDV_Based_Test_Report.pdf.']);
                    fileCreated = dir(fullfile(testCase.ProjectDir, 'DO_04_Code', 'verification_results', 'code_coverages', testCase.ModelNames{i}, 'host', 'LLR', [testCase.ModelNames{i}, '_SLDV_Based_Code_Coverage_Report.html']));
                    testCase.verifyEqual(isempty(fileCreated), false, ['Code Coverage Report not created: ', testCase.ModelNames{i}, '_SLDV_Based_Code_Coverage_Report.html.']);
                end
            end
        end
        
        function testMergeCodeCoverage(testCase)
            % This test case checks if Cumulative Code Coverage Reports
            % generated from models are successfully created by
            % "mergeCodeCoverage".
            
            % Test generation of Cumulative Code Coverage Reports from
            % models in the project.
            for i=1:numel(testCase.ModelNames)
                if exist(fullfile(testCase.ProjectDir, 'DO_04_Code', 'verification_results', 'eoc_test_results', testCase.ModelNames{i}, 'host', 'HLR', 'instrumented', [testCase.ModelNames{i}, '_INSTR_SIL_REQ_Based_Test_Results.mldatx']), 'file') ...
                        && exist(fullfile(testCase.ProjectDir, 'DO_04_Code', 'verification_results', 'eoc_test_results', testCase.ModelNames{i}, 'host', 'LLR', 'instrumented', [testCase.ModelNames{i}, '_INSTR_SIL_SLDV_Based_Test_Results.mldatx']), 'file')
                    mergeCodeCoverage(testCase.ModelNames{i}, 'SIL');
                    fileCreated = dir(fullfile(testCase.ProjectDir, 'DO_04_Code', 'verification_results', 'code_coverages', testCase.ModelNames{i}, 'host', [testCase.ModelNames{i}, '_Merged_Code_Coverage_Report.html']));
                    testCase.verifyEqual(isempty(fileCreated), false, ['Cumulative Code Coverage Report not created: ', testCase.ModelNames{i}, '_Merged_Code_Coverage_Report.html.']);
                end
            end
            
            % Close all HTML documents opened via MATLAB.
            [~, h] = web();
            h.close();
        end
    end
    
    methods(Static)
    end
end
