// This module wraps up the utility functions which can be used by any script
import { SaleTypes, StageTypes } from './constants';

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
