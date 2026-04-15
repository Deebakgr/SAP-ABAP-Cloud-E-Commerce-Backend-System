@EndUserText.label: 'User Behavior Consumption'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_ECOM_BEHAVIOR
  provider contract transactional_query
  as projection on ZI_ECOM_BEHAVIOR
{
  @Search.defaultSearchElement: true
  key EventId,
  
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_ECOM_USERS', element: 'UserId' } }]
  @Search.defaultSearchElement: true
  UserId,
  
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_ECOM_PRODUCT', element: 'ProductId' } }]
  @Search.defaultSearchElement: true
  ProductId,
  
  @Search.defaultSearchElement: true
  EventType,
  
  EventScore,
  SessionId,
  DeviceType,
  SearchKeyword,
  EventDate,
  EventTime,
  EventCriticality,
  EventTs,

  /* Associations */
  _User,
  _Product
}
