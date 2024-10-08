USE [SDBC_Inventory]
GO
/****** Object:  StoredProcedure [dbo].[inventory_action]    Script Date: 5/11/2023 2:06:52 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[inventory_action]
  @action nvarchar(50),
  @itemId nvarchar(50), 
  @quantity float,
  @timestamp datetime,
  @device nvarchar(50)
AS
BEGIN
  -- SET NOCOUNT ON added to prevent extra result sets from interfering with SELECT statements.
  SET NOCOUNT ON;
  DECLARE @oldQuantity float
  DECLARE @newQuantity float

  SET @action = LOWER(@action)
  SET @itemId = TRIM(@itemId)

  IF @itemId = ''
    SELECT 'Item-ID may not be empty';

  -- inventory_add action
  IF @action = 'inventory_add'
  BEGIN
    BEGIN TRAN 
    IF EXISTS (SELECT * FROM dbo.Inventory WHERE ItemId = @itemId) 
    BEGIN 
      SET @oldQuantity = (SELECT Quantity FROM dbo.Inventory WHERE ItemId = @itemId)
      SET @newQuantity = @oldQuantity + @quantity
      UPDATE dbo.Inventory SET Quantity = @newQuantity WHERE ItemId = @itemId

	  -- Add the information to the Inventory Log.
	  INSERT INTO dbo.InventoryLog (ItemId, Quantity, Action, UserName, Timestamp)
      VALUES (@itemId, @quantity, @action, @device, @timestamp)

      SELECT CONCAT ('Thank you, ',@device,'. As of ',@timestamp,'. There are now (', FORMAT(@newQuantity, N'0.######'), ') ',  @itemId, ' in stock');
    END 
    ELSE 
    BEGIN 
      SELECT CONCAT (@itemId, ' not found. Use the ''Set'' action to add a new Item.')
    END
    COMMIT TRAN
  END
  ELSE
  -- inventory_subtract action
  IF @action = 'inventory_subtract'
  BEGIN
    BEGIN TRAN 
    IF EXISTS (SELECT * FROM dbo.Inventory WHERE ItemId = @itemId) 
    BEGIN 
      SET @oldQuantity = (SELECT Quantity FROM dbo.Inventory WHERE ItemId = @itemId)
      SET @newQuantity = @oldQuantity - @quantity
      UPDATE dbo.Inventory SET Quantity = @newQuantity WHERE ItemId = @itemId

      SELECT CONCAT ('Thank you, ',@device,'. Please confirm that there are now (', FORMAT(@newQuantity, N'0.######'), ') ',  @itemId, ' in stock.');
	  -- Add the information to the Inventory Log.
	  INSERT INTO dbo.InventoryLog (ItemId, Quantity, Action, UserName, Timestamp)
      VALUES (@itemId, -@quantity, @action, @device, @timestamp)
      IF @newQuantity < 0
      BEGIN
        SELECT CONCAT('Resulting quantity for Item-ID: ', @itemId, ' is negative (', FORMAT(@newQuantity, N'0.######'), ')');
      END
    END 
    ELSE
    BEGIN
      SELECT CONCAT (@itemId, ' not found. Use the ''Set'' action to add a new Item.')
    END
    COMMIT TRAN
  END
  ELSE
 
 -- inventory_set action
 IF @action = 'inventory_set'
 BEGIN
  begin tran 
   if exists (select * from dbo.Inventory where ItemId = @itemId) 
   begin 
    UPDATE dbo.Inventory set Quantity = @quantity where ItemId = @itemId 
   end 
   else 
   begin 
    insert into dbo.Inventory (ItemId, Quantity) values (@itemId, @quantity) 
   end
   SELECT CONCAT ('Thank you, ',@device,'. As of ',@timestamp,'. There are (', FORMAT(@quantity, N'0.######'), ') ',  @itemId, ' in stock');
   -- Add the information to the Inventory Log.
   INSERT INTO dbo.InventoryLog (ItemId, Quantity, Action, UserName, Timestamp)
   VALUES (@itemId, @quantity, @action, @device, @timestamp)
  commit tran
 END
 ELSE
 -- inventory_subtract action
 IF @action = 'inventory_query'
 BEGIN
  begin tran 
  if exists (select * from dbo.Inventory where ItemId = @itemId) 
  begin 
   SELECT CONCAT('Current quantity for Item-ID ', @itemId, ' is ', FORMAT((SELECT Quantity FROM dbo.Inventory WHERE ItemId = @itemId), N'0.######'))
   commit tran
  end 
  else
   SELECT CONCAT (@itemId, ' not found.')
 END
END