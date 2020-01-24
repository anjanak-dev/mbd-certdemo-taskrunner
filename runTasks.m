function runTasks(taskList, varargin)

origDir = pwd;
disp(origDir);
restoreDir = onCleanup(@()cd(origDir));

cleanUpOnce = onCleanup(@()taskList.cleanupOnce());

taskList.setupOnce();

err = runEveryTask(taskList, varargin{:});

% disp(([keys(taskList.TaskStatus)' values(taskList.TaskStatus)']));
taskStatusData = createTaskStatusData(taskList);
taskReport = TaskReport;
taskReport.createTaskTable(taskStatusData);

if ~isempty(err)
    rethrow(err);
end

end



function err = runEveryTask(taskList, varargin)
err = [];
if nargin > 1
    taskName = varargin{1};
    cleanUpEachTask = onCleanup(@()taskList.cleanupEachTask());
    taskList.setupEachTask();
    fprintf('== Running task: %s == \n', taskName);
    try
        taskList.(taskName);
    catch me
        taskList.TaskStatus(taskName) = false;
        err = me;
        return;
    end
    taskList.TaskStatus(taskName) = true;
else
    tasks = taskList.TaskOrder;
    for idx = 1:length(tasks)
        err = runEveryTask(taskList, tasks(idx));
        if ~isempty(err)
            return;
        end
    end
end

end

function taskStatusData = createTaskStatusData(taskList)
taskStatusData = {};
for idx = 1:length(taskList.TaskOrder)
        taskStatusData(end+1,:) = {taskList.TaskOrder(idx), taskList.TaskStatus(taskList.TaskOrder{idx})};
end
end