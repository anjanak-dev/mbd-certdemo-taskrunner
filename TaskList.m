classdef (Abstract) TaskList < handle
    
    properties(Abstract)
        TaskOrder
    end
    
    properties
        TaskStatus
    end
    
    methods(Abstract)
        setupOnce(obj)
        
        
        setupEachTask(obj)
        
        
        cleanupEachTask(obj)
        
        
        cleanupOnce(obj)
    end
    
    methods
        function obj = TaskList(obj)
        
            taskStatus = containers.Map(obj.TaskOrder, zeros(length(obj.TaskOrder),1));
            obj.TaskStatus = taskStatus;
        end
        
    end
end