/* Name: QueueableJobsHandler
Description : Interface that defines handler methods for chained queueable jobs
Author : Raja Karuppasamy
*/
public interface QueueableJobsHandler {

    //Handler for each queueable job completion
    void handleSingleBatchCompletion(Id parentId, Integer successCount);

    //Handler when the entire job completes/for the last queueable job
    void handleAllJobsCompletion(Id parentId, Integer successCount);
}