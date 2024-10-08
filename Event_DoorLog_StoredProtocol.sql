USE [SDBC_Events]
GO
/****** Object:  StoredProcedure [dbo].[eventAttendance_action]    Script Date: 5/11/2023 11:57:39 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER   PROCEDURE [dbo].[eventAttendance_action]
  @action nvarchar(50),
  @attendeeId nvarchar(50),
  @timestamp datetime,
  @device nvarchar(50)
AS
BEGIN
 -- SET NOCOUNT ON added to prevent extra result sets from
 -- interfering with SELECT statements.
 SET NOCOUNT ON;
 DECLARE @msg nvarchar(MAX)

 DECLARE @checkIn datetime
 DECLARE @entryId nvarchar(50)
 DECLARE @checkOut datetime
 DECLARE @exitId nvarchar(50)

 SET @action = LOWER(@action)
 SET @attendeeId = TRIM(@attendeeId)

 IF @attendeeId = ''
  THROW 56002, 'Attendee-ID may not be empty', 1;

 begin tran
 -- read existing record
 SELECT
  @checkIn = CheckIn,
  @entryId = EntryId,
  @checkOut = CheckOut,
  @exitId = ExitId
 FROM
  dbo.EventAttendance
 WHERE
  AttendeeId = @attendeeId


 -- event_checkin action
 IF @action = 'event_checkin'
 BEGIN
  -- check if already checked in
  IF EXISTS (SELECT * FROM dbo.EventAttendance WHERE AttendeeId = @attendeeId AND EntryId = @device AND ExitId IS NULL)
  BEGIN
    SELECT CONCAT(@device, ' is still checked into ', @attendeeId, ' but has not checked out, please do so first.')
  END
  ELSE
  BEGIN
  -- Add a new row
    INSERT INTO dbo.EventAttendance (AttendeeId, CheckIn, EntryId) VALUES (@attendeeId, @timestamp, @device)
	SELECT CONCAT('Welcome ', @device, ', you are checking-in to ', @attendeeId, ' at ', @timestamp)
	END
	IF (@attendeeId IN ('EEP Grad Office','EEP 109','EEP 230','EEP 245') AND NOT EXISTS (SELECT * FROM dbo.EventAttendance WHERE AttendeeId = 'EEP Main Door' AND EntryId = @device AND ExitId IS NULL))
	BEGIN
	INSERT INTO dbo.EventAttendance (AttendeeId, CheckIn, EntryId) VALUES ('EEP Main Door', @timestamp, @device)
	END
 END
 ELSE
 -- event_checkout action
 IF @action = 'event_checkout'
 BEGIN
  -- check if already checked in
  IF @checkIn is NULL
  BEGIN
   SELECT CONCAT(@device,' is not checked in.');
  END
  -- check if already checked out
  IF @checkOut is not NULL
  BEGIN
   SELECT CONCAT(@device, ' is already checked out of ', @attendeeId);
  END
  -- Use 'EEP Main' as a log out of all other rooms in EEP as, you know, elvis and all.
  IF @attendeeId = 'EEP Main Door'
  BEGIN
    -- Update CheckOut and ExitId for all other doors if they have an EntryId but no ExitId
    UPDATE dbo.EventAttendance
    SET CheckOut = @timestamp, ExitId = @device
    WHERE AttendeeId IN ('EEP Main Door','EEP Grad Office','EEP 109','EEP 230','EEP 245')
        AND EntryId = @device
        AND ExitId IS NULL
  END
  ELSE
  BEGIN
    -- Update CheckOut and ExitId only for the current door if the user has an EntryId but no ExitId
    UPDATE dbo.EventAttendance
    SET CheckOut = @timestamp, ExitId = @device
    WHERE AttendeeId = @attendeeId
        AND EntryId = @device
        AND ExitId IS NULL
  END
  SELECT CONCAT(@device, ' checked out of ', @attendeeId, ' at ', @timestamp);
 END
 ELSE

 -- event_query_attendance action
 IF @action = 'event_query_attendance'
 BEGIN
  -- check if record exists
  if not exists (select * from dbo.EventAttendance where AttendeeId = @attendeeId) 
   THROW 56001, 'Attendee-ID not found', 1;

  SELECT 
   @checkIn AS CheckIn,
   @entryId AS EntryId,
   @checkOut AS CheckOut,
   @exitId AS ExitId
 END
 
 commit tran
END