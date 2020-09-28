/* Name: CrudFlsUtility
Description : Utility class that contains methods to help in CRUD & FLS checks
Author : Raja Karuppasamy
*/
public with sharing class CrudFlsUtility {
    /*
    Purpose:    Used to check CRUD & FLS access for the logged in user using StripInaccessible feature
    Input(s):   records - List of Sobjects that you either queried already or going to be used in DML
                accessCheck - AccessType enum - CREATABLE/READBLE/UPDATABLE/UPSERTABLE
                checkCRUD - Flag to enforce CRUD check
                checkFLS - Flag to enforce FLS check on the fields present in the sobjects
    Returns:    ApexResponse. status = true if Check/FLS check is successful.
                              records = stripped sobjects with accessible field values
                              errorMessage = Message that states all objects and fields which miss CRUD/FLS
    */
    public static ApexResponse checkCRUDandFLSpermissions(List<SObject> records, AccessType accessCheck,Boolean checkCRUD, Boolean checkFLS){
        ApexResponse response = new ApexResponse();
        if(!records.isEmpty()){
            Schema.DescribeSObjectResult baseObjDescribe = records[0].getSObjectType().getDescribe();
            try{
                SObjectAccessDecision securityDecision = Security.stripInaccessible(accessCheck, records, checkCRUD);
                if(!securityDecision.getRemovedFields().isEmpty()){
                    String errorMessage = '';
                    String objsMissingCRUD = extractChildObjsMissingCRUD(securityDecision.getRemovedFields(), baseObjDescribe);
                    if(checkCRUD && String.isNotBlank(objsMissingCRUD)){              
                        errorMessage += 'Insufficient permission setup for object(s): '+objsMissingCRUD;
                    }
                    String fieldsMissingFLS = extractFlsMissingFields(securityDecision.getRemovedFields(), accessCheck);
                    if(checkFLS && String.isNotBlank(fieldsMissingFLS)){
                        errorMessage += 'Insufficient permission setup for object(s): '+fieldsMissingFLS;
                    }
                    if(String.isNotBlank(errorMessage)){
                        throw new CustomException(errorMessage); 
                    }                                   
                }
                if(!securityDecision.getRecords().isEmpty()){
                    response.records = securityDecision.getRecords();             
                }
                response.status = true;
                response.errorMessage = '';                
            } catch(CustomException e){
                response.errorMessage = e.getMessage();
            } catch(NoAccessException e){
                response.errorMessage = 'Insufficient permission setup for object(s): '+baseObjDescribe.getLabel();
            } catch(Exception e){
                response.errorMessage = 'Application has encountered an unexpected error: '+ e.getMessage();
            }
        }
        return response;
    }

    //Helper method for checkCRUDandFLSpermissions
    private static String extractChildObjsMissingCRUD(Map<String,Set<String>> fieldsMap, DescribeSObjectResult baseObjDescribe){
        String objectLabelsStr = '';
        if(fieldsMap.containsKey(baseObjDescribe.getName())){
            Map<String,String> childRelsMap = new Map<String,String>();
            for(Schema.ChildRelationship childRel :baseObjDescribe.getChildRelationships()){
                childRelsMap.put(childRel.getRelationshipName(), childRel.getChildSObject().getDescribe().getLabel());
            }
            for(String baseObjFieldName :fieldsMap.get(baseObjDescribe.getName())){
                if(childRelsMap.containsKey(baseObjFieldName)){
                    objectLabelsStr += ', '+childRelsMap.get(baseObjFieldName);
                }
            }
        }
        return objectLabelsStr.removeStart(', ');
    }    

    //Helper method for checkCRUDandFLSpermissions
    private static String extractFlsMissingFields(Map<String,Set<String>> fieldsMap, AccessType accessCheck){
        String fieldLabelsStr = '';
        Set<String> fieldLabels = new Set<String>();
        for(String objName : fieldsMap.keySet()){
            Map<String, String> fieldLabelsMap = convertFieldNamesIntoLabels(fieldsMap.get(objName), objName, accessCheck);
            fieldLabels.addAll(fieldLabelsMap.values());
        }       
        if(!fieldLabels.isEmpty()){
            fieldLabelsStr = String.join(new List<String>(fieldLabels), ', ');
        }
        return fieldLabelsStr;
    }
    
    //Helper method for checkCRUDandFLSpermissions
    private static Map<String, String> convertFieldNamesIntoLabels(Set<String> fieldNames, String objName, AccessType accessCheck){
        Map<String, String> returnMap = new Map<String, String>();
        Map<String,Schema.SObjectField> fieldsSchema = Schema.getGlobalDescribe().get(objName).getDescribe().fields.getMap();
        for(String fieldName : fieldNames)
        {
            if(fieldsSchema.get(fieldName) != null){
                SObjectField fieldSchema = fieldsSchema.get(fieldName);
                if(accessCheck == AccessType.UPDATABLE && fieldsSchema.get(fieldName).getDescribe().isCalculated()) {
                    continue;
                } else{
                    returnMap.put(fieldName, fieldSchema.getDescribe().getlabel());
                }
            }
        }
        return returnMap;
    }
}
