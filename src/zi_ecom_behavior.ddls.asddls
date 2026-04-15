@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'User Behavior Interface View'
define  root view entity ZI_ECOM_BEHAVIOR
  as select from zecom_behavior
  association [0..1] to ZI_ECOM_USERS    as _User    on $projection.UserId    = _User.UserId
  association [0..1] to ZI_ECOM_PRODUCT as _Product on $projection.ProductId = _Product.ProductId
{
  key event_id       as EventId,
      user_id        as UserId,
      product_id     as ProductId,
      event_type     as EventType,
      event_score    as EventScore,
      session_id     as SessionId,
      device_type    as DeviceType,
      search_keyword as SearchKeyword,
      event_date     as EventDate,
      event_time     as EventTime,
      
      case event_type
        when 'VIEW'        then 5  // Blue
        when 'ADD_TO_CART' then 4  // Grey/Purple
        when 'CART'        then 4  // Grey/Purple
        when 'PURCHASE'    then 3  // Green
        when 'WISHLIST'    then 2  // Yellow
        when 'SEARCH'      then 2  // Yellow
        else 0
      end as EventCriticality,
      
      @Semantics.systemDateTime.lastChangedAt: true // Helps the ETag framewor
      event_ts       as EventTs,

      /* Public Associations */
      _User,
      _Product
}
