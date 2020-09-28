/* Name: QueueableJobsHandler
Description : Generic wrapper class to send response from Apex to Aura/LWC 
Author : Raja Karuppasamy
*/
public with sharing class ApexResponse {
    @AuraEnabled
    public Boolean status;
    @AuraEnabled
    public String errorMessage;    
    @AuraEnabled
    public String data;
    @AuraEnabled
    public List<Sobject> records;    

    public ApexResponse() {
        this.status = false;
        this.errorMessage = null;        
        this.data = null;
        this.records = null;
    }    
    
    public ApexResponse(Boolean status, string errorMessage, String data) {
        this.status = status;
        this.errorMessage = errorMessage;        
        this.data = data;
        this.records = null;
    }

    public ApexResponse(Boolean status, string errorMessage, List<Sobject> records) {
        this.status = status;
        this.errorMessage = errorMessage;        
        this.records = records;
        this.data = null;
    }    
}