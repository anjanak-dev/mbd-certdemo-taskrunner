classdef MockTaskList < TaskList
    properties
        TaskOrder = ["task_hello"
                     "task_dowork"
                     "task_goodbye"];
    end
                 
    methods
        function setupOnce(~)
        
        end
        
        function setupEachTask(~)
        
        end
        
        function cleanupEachTask(~)
        
        end
        
        function cleanupOnce(~)
        
        end
    end
    
    methods
        function task_hello(~)
            disp("hello world :)");
        end
        
        function task_dowork(~)
            disp("doing work..........");
        end
        
        function task_goodbye(~)
            disp("goodbye cruel world");
            assert(false, "ERRORRRR");
        end
    end
end