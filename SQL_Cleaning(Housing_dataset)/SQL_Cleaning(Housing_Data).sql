/*
Cleaning Data in SQL
SQL Type: TSQL
*/


--------------------------------------------------------------------------------------------------------------------------
-- Standardize Date Format


SELECT saleDate, CONVERT(DATE, SaleDate)
FROM Project3.dbo.NashvilleHousing


ALTER TABLE Project3.dbo.NashvilleHousing
ADD SaleDateConverted DATE;

UPDATE Project3.dbo.NashvilleHousing
SET SaleDateConverted = CONVERT(DATE, SaleDate)


 --------------------------------------------------------------------------------------------------------------------------
-- Populate Property Address data


SELECT *
FROM Project3.dbo.NashvilleHousing
WHERE PropertyAddress IS NULL

--(If there are duplicate 'Parcelid' values with NULL 'PropertyAddress' values,
--we can replace the NULL value with the correct 'PropertyAddress' value using the 'Parcelid' field as reference)


SELECT a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress, ISNULL(a.PropertyAddress, b.PropertyAddress)
FROM Project3.dbo.NashvilleHousing a
JOIN Project3.dbo.NashvilleHousing b
	ON a.ParcelID = b.ParcelID
	AND a.UniqueID <> b.UniqueID 
WHERE a.PropertyAddress IS NULL


UPDATE a
SET PropertyAddress = ISNULL(a.PropertyAddress, b.PropertyAddress)
FROM Project3.dbo.NashvilleHousing a
JOIN Project3.dbo.NashvilleHousing b
	ON a.ParcelID = b.ParcelID
	AND a.UniqueID <> b.UniqueID
WHERE a.PropertyAddress IS NULL


--------------------------------------------------------------------------------------------------------------------------
-- Breaking out Address into Individual Columns (Address, City, State)
-- For Property Address


SELECT PropertyAddress
FROM Project3.dbo.NashvilleHousing


SELECT
	SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) -1) AS Address,
	SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) + 1, LEN(PropertyAddress)) AS City
FROM Project3.dbo.NashvilleHousing


ALTER TABLE Project3.dbo.NashvilleHousing
ADD PropertySplitAddress NVARCHAR(100);

UPDATE Project3.dbo.NashvilleHousing
SET PropertySplitAddress = SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) -1)


ALTER TABLE Project3.dbo.NashvilleHousing
ADD PropertySplitCity NVARCHAR(100);

Update Project3.dbo.NashvilleHousing
SET PropertySplitCity = SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) + 1 , LEN(PropertyAddress))


Select *
From Project3.dbo.NashvilleHousing


--------------------------------------------------------------------------------------------------------------------------
-- Breaking out Address into Individual Columns (Address, City, State)
-- For Owner Address


SELECT OwnerAddress
FROM Project3.dbo.NashvilleHousing


SELECT
	PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3),
	PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2),
	PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1)
FROM Project3.dbo.NashvilleHousing


ALTER TABLE Project3.dbo.NashvilleHousing
ADD OwnerSplitAddress NVARCHAR(100);

UPDATE Project3.dbo.NashvilleHousing
SET OwnerSplitAddress = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3)


ALTER TABLE Project3.dbo.NashvilleHousing
ADD OwnerSplitCity NVARCHAR(50);

UPDATE Project3.dbo.NashvilleHousing
SET OwnerSplitCity = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2)


ALTER TABLE Project3.dbo.NashvilleHousing
ADD OwnerSplitState NVARCHAR(10);

UPDATE Project3.dbo.NashvilleHousing
SET OwnerSplitState = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1)



Select *
From Project3.dbo.NashvilleHousing


--------------------------------------------------------------------------------------------------------------------------
-- Change Y and N to Yes and No in "Sold as Vacant" field


SELECT DISTINCT(SoldAsVacant), COUNT(SoldAsVacant)
FROM Project3.dbo.NashvilleHousing
GROUP BY SoldAsVacant
ORDER BY 2


SELECT SoldAsVacant,
	CASE
		WHEN SoldAsVacant = 'Y' THEN 'Yes'
		WHEN SoldAsVacant = 'N' THEN 'No'
		ELSE SoldAsVacant
	END
FROM Project3.dbo.NashvilleHousing


UPDATE Project3.dbo.NashvilleHousing
SET SoldAsVacant = CASE
						WHEN SoldAsVacant = 'Y' THEN 'Yes'
						WHEN SoldAsVacant = 'N' THEN 'No'
						ELSE SoldAsVacant
					END


-----------------------------------------------------------------------------------------------------------------------------------------------------------
-- Remove Duplicates


WITH RowNumCTE AS(
SELECT *,
	ROW_NUMBER() OVER (
	PARTITION BY ParcelID,
				 SalePrice,
				 SaleDate,
				 LegalReference
	ORDER BY
				 UniqueID
				 ) row_num

FROM Project3.dbo.NashvilleHousing
)
SELECT *
FROM RowNumCTE
WHERE row_num > 1
ORDER BY ParcelID


WITH RowNumCTE AS(
SELECT *,
	ROW_NUMBER() OVER (
	PARTITION BY ParcelID,
				 SalePrice,
				 SaleDate,
				 LegalReference
	ORDER BY
				 UniqueID
				 ) row_num
FROM Project3.dbo.NashvilleHousing
)
DELETE
FROM RowNumCTE
WHERE row_num > 1


---------------------------------------------------------------------------------------------------------
-- Delete Unused Columns


SELECT *
FROM Project3.dbo.NashvilleHousing


ALTER TABLE Project3.dbo.NashvilleHousing
DROP COLUMN SaleDate, PropertyAddress, OwnerAddress, TaxDistrict