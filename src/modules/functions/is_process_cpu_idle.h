#ifndef IS_PROCESS_CPU_IDLE_H
#define IS_PROCESS_CPU_IDLE_H

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>

bool is_process_cpu_idle(pid_t pid);

#endif
