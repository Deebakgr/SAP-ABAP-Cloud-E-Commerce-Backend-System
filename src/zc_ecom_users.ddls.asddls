@EndUserText.label: 'E-Commerce Users Consumption'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_ECOM_USERS
provider contract transactional_query
  as projection on ZI_ECOM_USERS
{
  @Search.defaultSearchElement: true
  key UserId,
  
  @Search.defaultSearchElement: true
  @Search.fuzzinessThreshold: 0.8
  Username,
  
  @Search.defaultSearchElement: true
  Email,
  
  Phone,
  Segment,
  SegmentCriticality,
  
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Country', element: 'Country' } }]
  Country,
  
  City,
  DateOfBirth,
  Gender,
  IsActive,
  CreatedAt,
  ChangedAt
}
