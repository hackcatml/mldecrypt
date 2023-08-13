#import "spawnpacchild.h"
#import <Foundation/Foundation.h>

extern int posix_spawnattr_set_ptrauth_task_port_np(posix_spawnattr_t * __restrict attr, mach_port_t port);
void spawnPacChild(int argc, char *argv[])
{
    char** argsToPass = malloc(sizeof(char*) * (argc + 2));
    for(int i = 0; i < argc; i++)
    {
        argsToPass[i] = argv[i];
    }
    argsToPass[argc] = "pac";
    argsToPass[argc+1] = NULL;

    pid_t targetPid = atoi(argv[argc - 1]);
    mach_port_t task;
    kern_return_t kr = KERN_SUCCESS;
    kr = task_for_pid(mach_task_self(), targetPid, &task);
    if(kr != KERN_SUCCESS) {
        printf("[spawnPacChild] Failed to obtain task port.\n");
        return;
    }
    printf("[spawnPacChild] Got task port %d for pid %d\n", task, targetPid);

    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);
    posix_spawnattr_set_ptrauth_task_port_np(&attr, task);

    uint32_t executablePathSize = 0;
    _NSGetExecutablePath(NULL, &executablePathSize);
    char *executablePath = malloc(executablePathSize);
    _NSGetExecutablePath(executablePath, &executablePathSize);

    int status = -200;
    pid_t pid;
    int rc = posix_spawn(&pid, executablePath, NULL, &attr, argsToPass, NULL);

    posix_spawnattr_destroy(&attr);
    free(argsToPass);
    free(executablePath);

    if(rc != KERN_SUCCESS)
    {
        printf("[spawnPacChild] posix_spawn failed: %d (%s)\n", rc, mach_error_string(rc));
        return;
    }

    do
    {
        if (waitpid(pid, &status, 0) != -1) {
            printf("[spawnPacChild] Child returned %d\n", WEXITSTATUS(status));
        }
    } while (!WIFEXITED(status) && !WIFSIGNALED(status));

    return;
}
