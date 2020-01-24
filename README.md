# mbd-certdemo-taskrunner
Task runner for MBD Certification demo

Try running:
>> runTasks(MockTaskList);

To view the CI Tasks:
>> edit('cert-ci-tasks/CITasks') %This is a TaskList version of testCI which is from Ren/Mark's CI repo.

To run the CI Tasks:
>> cd cert-ci-tasks
% Clone this repo into this folder http://svn.mi.mathworks.com/general_psp/DO_Gaps/trunk/src/CI/
>> runTasks(CITasks)
(NOTE: This runs locally but is broken on Jenkins at the moment.)
