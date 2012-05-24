module Data.Time.Lens
    ( -- * Time
      HasTime(..)
    , hours
    , minutes
    , seconds
      -- * Date
    , HasDay(..)
    , year
    , month
    , dayOfMonth
    , gregorianDay
      -- * Time zone
    , HasTimeZone(..)
    , tzMinutes
    , tzSummerOnly
    , tzName
      -- * Re-exports from "Data.Time"
    , T.Day
    , T.TimeOfDay
    , T.LocalTime
    , T.ZonedTime
    , T.getZonedTime
      -- * Re-exports from "Data.Lens.Common"
    , Lens
    , getL
    )
where

import Control.Category
import Prelude hiding ((.), id)
import Data.Lens.Common
import Data.Fixed
import qualified Data.Time as T

class HasTime a where
    time :: Lens a T.TimeOfDay

hours :: HasTime a => Lens a Int
hours = (lens T.todHour $ \x t -> t { T.todHour = x }) . time

minutes :: HasTime a => Lens a Int
minutes = (lens T.todMin $ \x t -> t { T.todMin = x }) . time

seconds :: HasTime a => Lens a Pico
seconds = (lens T.todSec $ \x t -> t { T.todSec = x }) . time

instance HasTime T.TimeOfDay where
    time = ntime $ iso id id

localTimeOfZonedTime :: Lens T.ZonedTime T.LocalTime
localTimeOfZonedTime =
    lens T.zonedTimeToLocalTime $
        \x t -> t { T.zonedTimeToLocalTime = x }

instance HasTime T.LocalTime where
    time = ntimeAdjustDay $
        lens T.localTimeOfDay $ \x t -> t { T.localTimeOfDay = x }

instance HasTime T.ZonedTime where
    time = time . localTimeOfZonedTime

instance HasTime T.UTCTime where
    time = time . iso (T.utcToLocalTime T.utc) (T.localTimeToUTC T.utc)

class HasDay a where
    day :: Lens a T.Day

gregorianDay :: HasDay a => Lens a (Integer,Int,Int)
gregorianDay = iso T.toGregorian (uncurry3 T.fromGregorian) . day

year :: HasDay a => Lens a Integer
year = lens (\(y,_,_) -> y) (\y (_,m,d) -> (y,m,d)) . gregorianDay

month :: HasDay a => Lens a Int
month = lens (\(_,m,_) -> m) (\m (y,_,d) -> (y,m,d)) . gregorianDay

dayOfMonth :: HasDay a => Lens a Int
dayOfMonth = lens (\(_,_,d) -> d) (\d (y,m,_) -> (y,m,d)) . gregorianDay

uncurry3 :: (a -> b -> c -> d) -> (a, b, c) -> d
uncurry3 f (a, b, c) = f a b c

instance HasDay T.Day where
    day = iso id id

instance HasDay T.LocalTime where
    day = lens T.localDay (\d s -> s { T.localDay = d })

instance HasDay T.ZonedTime where
    day = day . localTimeOfZonedTime

instance HasDay T.UTCTime where
    day = day . iso (T.utcToLocalTime T.utc) (T.localTimeToUTC T.utc)

class HasTimeZone a where
    timeZone :: Lens a T.TimeZone

tzMinutes :: HasTimeZone a => Lens a Int
tzMinutes = (lens T.timeZoneMinutes $ \x t -> t { T.timeZoneMinutes = x }) . timeZone

tzSummerOnly :: HasTimeZone a => Lens a Bool
tzSummerOnly = (lens T.timeZoneSummerOnly $ \x t -> t { T.timeZoneSummerOnly = x }) . timeZone

tzName :: HasTimeZone a => Lens a String
tzName = (lens T.timeZoneName $ \x t -> t { T.timeZoneName = x }) . timeZone

instance HasTimeZone T.ZonedTime where
    timeZone = lens T.zonedTimeZone $ \x t -> t { T.zonedTimeZone = x }

normalizeTime :: T.TimeOfDay -> (T.TimeOfDay, Integer)
normalizeTime = timeToTimeOfDay . timeOfDayToTime

-- Can't rely on a HasTime instance here because this function will be used to
-- define one
ntime :: Lens a T.TimeOfDay -> Lens a T.TimeOfDay
ntime time = iso id (fst . normalizeTime) . time

ntimeAdjustDay :: (HasDay a) => Lens a T.TimeOfDay -> Lens a T.TimeOfDay
ntimeAdjustDay time = lens (getL time) $ \t ->
    case normalizeTime t of
        (t', days) -> setL time t' . modL day (T.addDays days)

-- We don't use T.timeToTimeOfDay and T.timeOfDayToTime here for the following
-- reasons:
-- * T.timeOfDayToTime could potentially perform bounds checking (although its
-- current implementation doesn't)
-- * T.timeToTimeOfDay converts excess time to leap seconds
timeOfDayToTime :: T.TimeOfDay -> T.DiffTime
timeOfDayToTime (T.TimeOfDay h m s) = ((fromIntegral h) * 60 + (fromIntegral m)) * 60 + (realToFrac s)

timeToTimeOfDay :: T.DiffTime -> (T.TimeOfDay, Integer)
timeToTimeOfDay dt = (T.TimeOfDay (fromInteger h) (fromInteger m) s, d) where
    s' = realToFrac dt
    s = mod' s' 60
    m' = div' s' 60
    m = mod' m' 60
    h' = div' m' 60
    h = mod' h' 24
    d = div' h' 24
