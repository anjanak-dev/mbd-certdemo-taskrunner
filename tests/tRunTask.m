classdef tRunTask < matlab.unittest.TestCase
    methods(Test)
        function testRunOneTask(testCase)
            log = evalc('runTasks(MockTaskList, "task_hello")');
            testCase.verifySubstring(log, "hello world");
        end
        
        function testRunAll(testCase)
        
            log = evalc('runTasks(MockTaskList)');
            testCase.verifyThat(log, matlab.unittest.constraints.Matches(...
                'hello world.*doing work.*goodbye cruel world'));
        end
        
    end
end