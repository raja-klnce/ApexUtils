/* Name: ExecuteDmlQueuableBatches
Description :  Utility class that chunks list of sobject records and does DML by chained queuable jobs with 
               the desired batch size
Author : Raja Karuppasamy
*/
public with sharing class ExecuteDmlQueuableBatches implements Queueable {
    private Map<Integer, List<Sobject>>  records;
    private String action;      //insert or update or upsert or delete
    private Integer batchSize;
    private Integer currentBatch;
    private String finallyHandlerName;
    private Id parentId;
    private Integer successCount;    

    //Queueable Jobs kick-off
    public ExecuteDmlQueuableBatches(List<Sobject> recordsList, String action, Integer batchSize, Id parentId, String finallyHandlerName){
        this.records = batchOutDmls(recordsList, batchSize);
        this.action = action;
        this.batchSize = batchSize;
        this.currentBatch = 1;
        this.finallyHandlerName = finallyHandlerName;
        this.parentId = parentId;
        this.successCount = 0;
    }

    //Iterative Queueable job
    public ExecuteDmlQueuableBatches(Map<Integer, List<Sobject>>  records, String action, Integer batchSize, Integer currentBatch, String finallyHandlerName, Id parentId, Integer successCount){
        this.records = records;
        this.action = action;
        this.batchSize = batchSize;
        this.currentBatch = currentBatch;
        this.finallyHandlerName = finallyHandlerName;
        this.parentId = parentId;
        this.successCount = successCount;        
    }

    public void execute(QueueableContext context) {
        if(this.records.containsKey(this.currentBatch)){
            Boolean success = false;
            Integer processedRecords = 0;
            try {
                List<Sobject> thisBatchRecords = this.records.get(this.currentBatch);
                processedRecords = thisBatchRecords.size();
                switch on action {
                    when 'INSERT' {
                        insert thisBatchRecords;
                    }	
                    when 'UPDATE' {
                        update thisBatchRecords;
                    }
                    when 'UPSERT' {
                        upsert thisBatchRecords;
                    }
                    when 'DELETE' {
                        delete thisBatchRecords;
                    }
                }
                this.records.remove(this.currentBatch);
                success = true;
            } catch(Exception e){
                System.debug('Exception in queueable jobs chain ==> '+e.getMessage());
                //Handle your relevant custom exception handling and monitoring                
            }
            QueueableJobsHandler handler;
            if(String.isNotBlank(this.finallyHandlerName)){
                Type classType = Type.forName(this.finallyHandlerName);
                handler = (QueueableJobsHandler)classType.newInstance();                
            }            
            if(success) {
                if(this.successCount == null){
                    this.successCount = processedRecords;
                } else {
                    this.successCount += processedRecords;
                }
                if(handler != null){
                    handler.handleSingleBatchCompletion(this.parentId, this.successCount);
                }
            }

            Integer nextBatch = this.currentBatch + 1;
            if(this.records.containsKey(nextBatch) && Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()){
                //Chain jobs
                System.enqueueJob(new ExecuteDmlQueuableBatches(this.records, this.action, this.batchSize, nextBatch, this.finallyHandlerName, this.parentId, this.successCount));
            } else if(handler != null){
                //Invoke the finally callback
                handler.handleAllJobsCompletion(this.parentId, this.successCount);
            }
        } 
    }

    private Map<Integer, List<Sobject>> batchOutDmls(List<Sobject> recordsList, Integer batchSize){
        Map<Integer, List<Sobject>> batchMap = new Map<Integer, List<Sobject>>();
        if(batchSize <= 10000){
            Integer batchCurrSize = 0;
            Integer batchNumber = 1;
            List<Sobject> singleBatch = new List<Sobject>();    
            for (Integer i = 0; i < recordsList.size(); i++){
                if(batchCurrSize == batchSize){
                    batchMap.put(batchNumber, singleBatch);
                    singleBatch = new List<Sobject>();            
                    batchNumber++;
                    batchCurrSize = 0;
                }
                singleBatch.add(recordsList[i]);
                batchCurrSize++;
            }
            if(!singleBatch.isEmpty()){
                batchMap.put(batchNumber, singleBatch);
            } 
        } else {
            throw new CustomException('BatchSize cannot be more than 10k');
        }
        return batchMap;
    }
}