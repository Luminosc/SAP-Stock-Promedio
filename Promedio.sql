DECLARE @StartDate DATE = (SELECT MIN(DOCDATE) FROM OINM);
DECLARE @EndDate DATE = GETDATE();


DECLARE @Inicio DATE = @StartDate--'2024-01-01';
DECLARE @Fin DATE = GETDATE()-- '2010-12-31';

DECLARE @Numero VARCHAR(25) = 'A00001';
DECLARE @Descripcion VARCHAR(25)= 'IBM Infoprint 1312';


--Generador de días
WITH DateRange AS (
    SELECT @StartDate AS DateValue
    UNION ALL
    SELECT DATEADD(DAY, 1, DateValue)
    FROM DateRange
    WHERE DateValue < @EndDate
),
-- Subconsulta de dias
DATEDATA AS (
    SELECT T0.ItemCode, 
                T0.Dscription, 
                T0.DocDate, 
                SUM(T0.InQty) AS [SumIn], 
                SUM(T0.OutQty) AS [SumOut]
    FROM OINM T0
    WHERE T0.ItemCode = @Numero AND T0.DocDate <= @EndDate AND T0.Dscription = @Descripcion
    GROUP BY T0.ItemCode, T0.Dscription, T0.DocDate
),
-- Seleccion de valores por día
DATEDAYS AS(
SELECT T0.DateValue, 
            T1.ItemCode, 
            T1.Dscription,
            ISNULL(SUM(T1.SumIn), 0) AS TotalInQty,
            ISNULL(SUM(T1.SumOut), 0) AS TotalOutQty,
            ISNULL(SUM(T1.SumIn), 0) - ISNULL(SUM(T1.SumOut), 0) as Promedio
FROM DateRange T0 
LEFT JOIN DATEDATA T1 
    ON T0.DateValue >= T1.DocDate
GROUP BY T0.DateValue, T1.ItemCode, T1.Dscription
),

MONTHSDATA AS (
SELECT DISTINCT T0.DateValue,
            T0.ItemCode, 
            T0.Dscription,
            LAST_VALUE(T0.TotalInQty) OVER (PARTITION BY T0.ItemCode, DATEPART(YEAR, T0.DateValue), DATEPART(MONTH, T0.DateValue) ORDER BY T0.DateValue ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS UltimaEntrada,    
          LAST_VALUE(T0.TotalOutQty) OVER (PARTITION BY T0.ItemCode, DATEPART(YEAR, T0.DateValue), DATEPART(MONTH, T0.DateValue) ORDER BY T0.DateValue ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS UltimaSalida,   
          LAST_VALUE(T0.Promedio) OVER (PARTITION BY T0.ItemCode, DATEPART(YEAR, T0.DateValue), DATEPART(MONTH, T0.DateValue) ORDER BY T0.DateValue ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS UltimoPromedio

FROM DATEDAYS T0
GROUP BY T0.DateValue, T0.ItemCode, T0.Dscription, T0.TotalInQty, T0.TotalOutQty, T0.Promedio
),

ULTIMATEDATE AS (
SELECT T0.ItemCode,
            T0.DateValue,
            T0.Dscription,
            T0.UltimaEntrada,
            T0.UltimaSalida,
            T0.UltimoPromedio as Stock,
            SUM(T0.UltimoPromedio)  OVER (PARTITION BY ItemCode ORDER BY DateValue) as SumStock,
            (SUM(T0.UltimoPromedio)  OVER (PARTITION BY ItemCode ORDER BY DateValue))/ (COUNT(T0.ItemCode) OVER (PARTITION BY ItemCode ORDER BY DateValue)) as Promedio
FROM MONTHSDATA T0
GROUP BY T0.DateValue, T0.ITEMCODE, T0.DSCRIPTION, T0.ULTIMAENTRADA, T0.ULTIMASALIDA, T0.UltimoPromedio)


SELECT DISTINCT FORMAT(T0.DateValue,'yyyy/MM'),
            T0.ItemCode, 
            T0.Dscription,
            LAST_VALUE(T0.UltimaEntrada) OVER (PARTITION BY T0.ItemCode, DATEPART(YEAR, T0.DateValue), DATEPART(MONTH, T0.DateValue) ORDER BY T0.DateValue ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS Entrada,    
            LAST_VALUE(T0.UltimaSalida) OVER (PARTITION BY T0.ItemCode, DATEPART(YEAR, T0.DateValue), DATEPART(MONTH, T0.DateValue) ORDER BY T0.DateValue ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS Salida,
            LAST_VALUE(T0.Stock) OVER (PARTITION BY T0.ItemCode, DATEPART(YEAR, T0.DateValue), DATEPART(MONTH, T0.DateValue) ORDER BY T0.DateValue ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS Stock,
            LAST_VALUE(T0.SumStock) OVER (PARTITION BY T0.ItemCode, DATEPART(YEAR, T0.DateValue), DATEPART(MONTH, T0.DateValue) ORDER BY T0.DateValue ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS [Suma de Stock],
            LAST_VALUE(T0.Promedio) OVER (PARTITION BY T0.ItemCode, DATEPART(YEAR, T0.DateValue), DATEPART(MONTH, T0.DateValue) ORDER BY T0.DateValue ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS [Promedio de Stock]
FROM ULTIMATEDATE T0
WHERE T0.DateValue between @Inicio AND @Fin
GROUP BY T0.DATEVALUE, T0.ITEMCODE, T0.DSCRIPTION, T0.ULTIMAENTRADA, T0.ULTIMASALIDA, T0.PROMEDIO, T0.stock, t0.SumStock
OPTION (MAXRECURSION 0);