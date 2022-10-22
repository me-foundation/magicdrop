// This module wraps up the utility functions which can be used by any script

export const SaleTypes = {
  ERC721M: { enumVal: 0, strVal: 'ERC721M' }, // The contract of direct sales
  BucketAuction: { enumVal: 1, strVal: 'BucketAuction' }, // The contract of bucket auctions
};

export const StageTypes = {
  Public: { enumVal: 0, strVal: 'Public' }, // Stage where any wallet can buy
  WhiteList: { enumVal: 1, strVal: 'WhiteList' }, // Stage where only predetermined wallets can buy
};

const getPropertyByCaseInsensitiveName = (
  objectClass: object,
  propertyName: string,
  defaultValue: any,
) => {
  const foundEnumValues = Object.entries(objectClass)
    .filter(([key, value]) => isEquivalent(value.strVal, propertyName))
    .map(([key, value]) => {
      return value.enumVal;
    });

  return foundEnumValues.length > 0 ? foundEnumValues[0] : defaultValue;
};

export const getStageEnumValueByName = (stageTypeName: string) => {
  return getPropertyByCaseInsensitiveName(StageTypes, stageTypeName, 0);
};

export const getSaleEnumValueByName = (saleTypeName: string) => {
  return getPropertyByCaseInsensitiveName(SaleTypes, saleTypeName, 0);
};

export const isEquivalent = (str1: string, str2: string) => {
  return (
    (!str1 && !str2) ||
    (str1 &&
      str1.localeCompare(str2, 'en', {
        sensitivity: 'accent',
      }) == 0)
  );
};
