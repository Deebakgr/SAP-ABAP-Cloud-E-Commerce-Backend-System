@EndUserText.label: 'E-Commerce Orders Consumption'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: ['OrderId']
define root view entity ZC_ECOM_ORDERS
  provider contract transactional_query
  as projection on ZI_ECOM_ORDERS
{
  @Search.defaultSearchElement: true
  key OrderId,
  
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_ECOM_USERS', element: 'UserId' } }]
  @Search.defaultSearchElement: true
  @ObjectModel.text.element: ['_User.Username']
  UserId,
  
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_ECOM_PRODUCT', element: 'ProductId' } }]
  @Search.defaultSearchElement: true
  @ObjectModel.text.element: ['_Product.ProductName']
  ProductId,
  
  Quantity,
  UnitPrice,
  TotalPrice,
  
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Currency', element: 'Currency' } }]
  Currency,
  
  DiscountPct,
  Status,
  StatusCriticality,
  PaymentMethod,
  DeliveryAddr,
  OrderDate,
  OrderTime,
  ShippedDate,
  DeliveredDate,
  CreatedBy,
  ChangedAt,

  /* Associations */
  _User,
  _Product
}
