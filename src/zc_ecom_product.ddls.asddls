@EndUserText.label: 'E-Commerce Products Consumption'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@Search.searchable: true
define root  view entity ZC_ECOM_PRODUCT
  provider contract transactional_query
  as projection on ZI_ECOM_PRODUCT
{
  @Search.defaultSearchElement: true
  key ProductId,
  
  @Search.defaultSearchElement: true
  @Search.fuzzinessThreshold: 0.8
  ProductName,
  
  @Search.defaultSearchElement: true
  Category,
  
  Brand,
  Price,
  
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Currency', element: 'Currency' } }]
  Currency,
  
  StockQty,
  Rating,
  IsActive,
  CreatedBy,
  CreatedAt,
  ChangedBy,
  ChangedAt
}
