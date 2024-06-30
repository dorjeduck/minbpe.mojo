#################
# This and that #
#################

from time import now
from utils import Variant

from .generic_dict import Keyable,KeysBuilder

alias IntOrString = Variant[Int, String]

struct MoBench:
    var start:Float32
    fn __init__(inout self,name:String = ""):
        self.start=now()
        if len(name):
            print(name)
    fn result(self,in_seconds:Bool=True):
        var elapsed = now()-self.start

        if in_seconds:
            print("time: " + str(elapsed/1_000_000_000) + " sec")
        else:
            print("time: " + str(elapsed) + " nsec")

@value
struct IntKey(Keyable):
    var key:Int32
    @always_inline("nodebug")
    fn accept[T: KeysBuilder](self, inout keys_builder: T):
        keys_builder.add(self.key)

fn distribute_jobs(n_jobs: Int, n_workers: Int, overlap: Int = 0) -> List[Int]:
    """
    Distribute n_jobs among n_workers and return a list of index boundaries for the job ranges.

    Parameters:
    n_jobs (int): Total number of jobs.
    n_workers (int): Total number of workers.

    Returns:
    List[int]: A list where each element i represents the starting index of the jobs for worker i.
               The last element is n_jobs, which serves as the end boundary for the last worker.
    """

    # Basic number of jobs per worker
    var jobs_per_worker = n_jobs // n_workers
    # Calculate the remainder to see if extra jobs need to be distributed
    var remainder = n_jobs % n_workers

    var boundaries = List[Int](capacity=n_workers + 1)
    var current_job = 0

    for i in range(n_workers):
        # Start from the current job
        boundaries.append(current_job)
        # Each worker gets the base number of jobs
        current_job += jobs_per_worker
        if i < remainder:
            # Distribute the remainder jobs one by one to the first 'remainder' workers
            current_job += 1
    # Append the total number of jobs to mark the end of the last range
    boundaries.append(n_jobs)
    return boundaries


fn print_list_str(x: List[String]) -> None:
    if len(x) == 0:
        return

    print("[", end="")
    for i in range(len(x) - 1):
        print(x[i], end=", ")
    print(str(x[-1]) + "]")


fn print_list_int(x: List[Int]) -> None:
    if len(x) == 0:
        return

    print("[", end="")
    for i in range(len(x) - 1):
        print(x[i], end=", ")
    print(str(x[-1]) + "]")
