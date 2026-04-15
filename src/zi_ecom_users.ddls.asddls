@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'E-Commerce Users Interface View'
define root view entity ZI_ECOM_USERS
  as select from zecom_users
{
  key user_id       as UserId,
      username      as Username,
      email         as Email,
      phone         as Phone,
      segment       as Segment,
      
      // Add this new calculated field for the colors!
      case segment
        when 'NEW'      then 4  // 2 = Yellow/Orange
        when 'STANDARD' then 5  // 5 = Blue
        when 'PREMIUM'  then 3  // 4 = Neutral/Dark
        else 0
      end as SegmentCriticality,
      
      country       as Country,
      city          as City,
      date_of_birth as DateOfBirth,
      gender        as Gender,
      is_active     as IsActive,
      created_at    as CreatedAt,
      changed_at    as ChangedAt
}
