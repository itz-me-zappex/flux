#ifndef IS_PROCESS_CPU_IDLE_H
#define IS_PROCESS_CPU_IDLE_H

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>

// Check whether process sleeps or not using '/proc/PID/status'
bool is_process_cpu_idle(pid_t pid) {
  char path[64];
  snprintf(path, sizeof(path), "/proc/%d/stat", pid);

  unsigned long utime1, stime1;
  unsigned long utime2, stime2;

  FILE *file = fopen(path, "r");
  if (!file) {
    return false;
  }

  char buf[4096];
  if (!fgets(buf, sizeof(buf), file)) {
    fclose(file);
    return false;
  }
  fclose(file);

  char *ptr = strrchr(buf, ')');
  if (!ptr) {
    return false;
  }
  ptr++;

  int field = 3;
  char *token = strtok(ptr, " ");
  while (token) {
    if (field == 14) {
      utime1 = strtoul(token, NULL, 10);
    } else if (field == 15) {
      stime1 = strtoul(token, NULL, 10);
      break;
    }
    token = strtok(NULL, " ");
    field++;
  }

  // Wait before 2nd check to get difference
  usleep(100000);

  file = fopen(path, "r");
  if (!file) {
    return false;
  }
  if (!fgets(buf, sizeof(buf), file)) {
    fclose(file);
    return false;
  }
  fclose(file);

  ptr = strrchr(buf, ')');
  if (!ptr) {
    return false;
  }
  ptr++;

  field = 3;
  token = strtok(ptr, " ");
  while (token) {
    if (field == 14) {
      utime2 = strtoul(token, NULL, 10);
    } else if (field == 15) {
      stime2 = strtoul(token, NULL, 10);
      break;
    }
    token = strtok(NULL, " ");
    field++;
  }

  // Get difference between 2 checks
  unsigned long delta = (utime2 + stime2) - (utime1 + stime1);
  
  // If nothing changed between two checks or difference is very small, then process hanged
  if (delta <= 2) {
    return true;
  }

  return false;
}

#endif
