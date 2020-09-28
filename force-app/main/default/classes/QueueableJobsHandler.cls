public interface QueueableJobsHandler {

    void handleSingleBatchCompletion(Id parentId, Integer successCount);

    void handleAllJobsCompletion(Id parentId, Integer successCount);
}