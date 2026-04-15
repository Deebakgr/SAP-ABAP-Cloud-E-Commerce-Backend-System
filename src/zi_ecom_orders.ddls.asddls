@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'E-Commerce Orders Interface View'
define root view entity ZI_ECOM_ORDERS
  as select from zecom_orders
  association [0..1] to ZI_ECOM_USERS    as _User    on $projection.UserId    = _User.UserId
  association [0..1] to ZI_ECOM_PRODUCT as _Product on $projection.ProductId = _Product.ProductId
{
  key order_id       as OrderId,
      user_id        as UserId,
      product_id     as ProductId,
      quantity       as Quantity,
      @Semantics.amount.currencyCode: 'Currency'
      unit_price     as UnitPrice,
      @Semantics.amount.currencyCode: 'Currency'
      total_price    as TotalPrice,
      currency       as Currency,
      discount_pct   as DiscountPct,
      status         as Status,
      
      // Add this new calculated field for the Status colors!
      case status
        when 'SHIPPED'   then 5  // Blue
        when 'CONFIRMED' then 3  // Green
        when 'PENDING'   then 2  // Yellow/Orange
        when 'CANCELLED' then 1  // Red
        when 'NEW'       then 2  // Yellow/Orange
        else 0
      end as StatusCriticality,
      
      payment_method as PaymentMethod,
      delivery_addr  as DeliveryAddr,
      order_date     as OrderDate,
      order_time     as OrderTime,
      shipped_date   as ShippedDate,
      delivered_date as DeliveredDate,
      created_by     as CreatedBy,
      changed_at     as ChangedAt,

      /* Public Associations */
      _User,
      _Product
}
