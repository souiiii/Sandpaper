#include <libproc.h>
#include <mach/mach.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/resource.h>
#include <sys/sysctl.h>

int main(int argc, char **argv) {
    int pid = argc > 1 ? atoi(argv[1]) : 0;
    struct rusage_info_v4 usage = {0};
    int process_ok = pid > 0 && proc_pid_rusage(pid, RUSAGE_INFO_V4, (rusage_info_t *)&usage) == 0;
    int pressure = -1;
    size_t size = sizeof(pressure);
    if (sysctlbyname("kern.memorystatus_vm_pressure_level", &pressure, &size, NULL, 0) != 0) pressure = -1;
    struct xsw_usage swap = {0};
    size = sizeof(swap);
    int swap_ok = sysctlbyname("vm.swapusage", &swap, &size, NULL, 0) == 0;
    vm_statistics64_data_t vm = {0};
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    int vm_ok = host_statistics64(mach_host_self(), HOST_VM_INFO64, (host_info64_t)&vm, &count) == KERN_SUCCESS;
    vm_size_t page_size = 0;
    host_page_size(mach_host_self(), &page_size);
    printf("{\"pid\":%d,\"processAvailable\":%s,\"residentBytes\":%llu,\"physicalFootprintBytes\":%llu,\"lifetimePeakFootprintBytes\":%llu,\"pressureLevel\":%d,\"swapAvailable\":%s,\"swapUsedBytes\":%llu,\"vmAvailable\":%s,\"compressorBytes\":%llu,\"swapInBytes\":%llu,\"swapOutBytes\":%llu}\n",
        pid, process_ok ? "true" : "false", usage.ri_resident_size, usage.ri_phys_footprint,
        usage.ri_lifetime_max_phys_footprint, pressure, swap_ok ? "true" : "false", swap.xsu_used,
        vm_ok ? "true" : "false", (unsigned long long)vm.compressor_page_count * page_size,
        (unsigned long long)vm.swapins * page_size, (unsigned long long)vm.swapouts * page_size);
    return 0;
}
