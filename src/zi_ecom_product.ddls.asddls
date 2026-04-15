@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'E-Commerce Products Interface View'
define root view entity ZI_ECOM_PRODUCT
  as select from zecom_products
{
  key product_id   as ProductId,
      product_name as ProductName,
      category     as Category,
      brand        as Brand,
      @Semantics.amount.currencyCode: 'Currency'
      price        as Price,
      currency     as Currency,
      stock_qty    as StockQty,
      rating       as Rating,
      is_active    as IsActive,
      created_by   as CreatedBy,
      created_at   as CreatedAt,
      changed_by   as ChangedBy,
      changed_at   as ChangedAt
}
