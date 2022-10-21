// This module wraps up the utility functions which can be used by any script

export const saleEnumValueByType = {
  ERC721M: 0, // The contract of direct sales
  BucketAuction: 1, // The contract of bucket auctions
};

const stageEnumValueByType = {
  Public: 0, // Stage where any wallet can buy
  WhiteList: 1, // Stage where only predetermined wallets can buy
};

const caseInsensitiveGetByPropertyName = (
  objectClass: object,
  propertyName: string,
  defaultValue: any,
) => {
  // Object.entries(objectClass).forEach((k, v) => console.log(`${k}`));
  const foundPropVal = Object.entries(objectClass)
    .filter(
      ([key, value]) =>
        key.localeCompare(propertyName, 'en', {
          sensitivity: 'base',
        }) == 0,
    )
    .map(([key, value]) => {
      return value;
    });

  return foundPropVal.length > 0 ? foundPropVal[0] : defaultValue;
};

export const getStageEnumValueByName = (stageTypeName: string) => {
  return caseInsensitiveGetByPropertyName(
    stageEnumValueByType,
    stageTypeName,
    0,
  );
};

export const getSaleEnumValueByName = (saleTypeName: string) => {
  return caseInsensitiveGetByPropertyName(saleEnumValueByType, saleTypeName, 0);
};
