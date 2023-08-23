@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'UI provider for online shop'
@Metadata.allowExtensions: true
define root view entity ZC_ONLINE_SHOP_LW01
  provider contract transactional_query
  as projection on ZR_ONLINE_SHOP_LW01
{
  key Order_Uuid,
      Order_Id,
      Deliverydate,
      Creationdate,
      PackageId,
      CostCenter,
      _Shop.purchasereqn as Purchasereqn
}
