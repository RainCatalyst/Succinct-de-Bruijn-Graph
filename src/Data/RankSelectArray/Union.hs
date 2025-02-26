module Data.RankSelectArray.Union where


import           Control.Applicative
import           Data.Maybe
import           Data.RankSelectArray.Class
import           Data.RankSelectArray.Diff


-- | Disjoint Union of two RankSelectArray
data Union a b = Union a b
    deriving (Eq, Show)

-- | Unions of multiple RankSelectArrays where a is a common part and b's are uniq part
data Unions a b = Unions a [b]
    deriving (Eq, Show)

-- | Combination of Union and Diff structure
type UnionDiff a b c = Union a (Diff b c)

-- | Combination of Unions and Diff structure
type UnionsDiff a b c = Unions a (Diff b c)


instance (RankSelectArray a, RankSelectArray b) => RankSelectArray (Union a b) where
  select = unionSelect
  rank = unionRank
  generateEmpty size = Union (generateEmpty size) (generateEmpty size)
  setBits arr bits = unionSetBits arr (map (\(ind, v) -> (ind, v, Left True)) bits)
  getSize (Union left right) = getSize left + getSize right
  getOneCount (Union left right) = getOneCount left + getOneCount right

-- ** Convert two ordered list to 'Unions'

-- | Convert two asc list to Unions Structure
-- The intersection of two arrays must be greater than 50%
fromListsAsc
  :: (RankSelectArray a, RankSelectArray b)
  => Int  -- ^ Size of left array
  -> Int  -- ^ Size of right array
  -> [Int] -- ^ Left ones
  -> [Int] -- ^ Right ones
  -> Unions a b
fromListsAsc leftSize rightSize left right = Unions commonArray [leftArray, rightArray]
  where
    commonPart = filter (\x -> x `elem` right) right
    commonSize = length commonPart + 1
    commonArray = fromOnes commonSize (length commonPart) commonPart
    leftPart = filter (\x -> not (x `elem` commonPart)) left
    rightPart = filter (\x -> not (x `elem` commonPart)) right
    leftArray = fromOnes leftSize (length leftPart) leftPart
    rightArray = fromOnes rightSize (length rightPart) rightPart


-- ** Update unions

-- | Add array into UnionsDiff, puts in front of uniqParts
addArrayToUnion
  :: (RankSelectArray a, RankSelectArray b, RankSelectArray c)
  => Int -- ^ Size of an array
  -> [Int] -- ^ Ones
  -> UnionsDiff a b c
  -> UnionsDiff a b c
addArrayToUnion size ones (Unions commonPart uniqParts) = Unions commonPart (newUniqPart:uniqParts)
  where
    commonOnes = toOnes commonPart
    rightDiffPart = filter (\x -> not (x `elem` ones)) commonOnes
    leftDiffPart = filter (\x -> not (x `elem` commonOnes)) ones
    newUniqPart = Diff (fromOnes size (length leftDiffPart) leftDiffPart) (fromOnes size (length rightDiffPart) rightDiffPart)

-- ** Select Union in Unions

-- | Get by index union
getUnion
  :: Int
  -> Unions a b
  -> Union a b
getUnion index (Unions commonPart uniqParts) = Union commonPart (uniqParts !! index)


-- ** Query operations from Union

-- | Left and right arrays must be disjoint
unionSelect
  :: (RankSelectArray a, RankSelectArray b)
  => Union a b
  -> Bool
  -> Int
  -> Int
unionSelect union@(Union left right) forOnes count
  | count > getOneCount union || count <= 0 = -1
  | otherwise = fromMaybe (-1) (leftResult <|> rightResult)
    where
      leftResult = ultimateBinarySearch left (const count) (const 0) (selectGetItem) rankCompare
      rightResult = ultimateBinarySearch right (const count) (const 0) (selectGetItem) rankCompare

      selectGetItem coll i = case select coll forOnes i of
                             -1 -> Nothing
                             v  -> Just v
      rankCompare v = compare count (unionRank union forOnes v)



-- | Left and right arrays must be disjoint
unionRank
  :: (RankSelectArray a, RankSelectArray b)
  => Union a b
  -> Bool
  -> Int
  -> Int
unionRank (Union left right) forOnes pos = rank left forOnes pos + rank right forOnes pos


-- ** Constructor for Union

-- | Left and right arrays must be disjoint
unionSetBits
  :: (RankSelectArray a, RankSelectArray b)
  => Union a b
  -> [(Int, Bool, Either l r)]
  -> Union a b
unionSetBits (Union left right) bits = Union newLeft newRight
  where
    newLeft = setBits left leftArrays
    newRight = setBits right rightArrays
    filterFunction isLeft (_, _, Left _)  = isLeft
    filterFunction isLeft (_, _, Right _) = not isLeft
    leftArrays = map (\(ind, value, _) -> (ind, value)) ((filter (filterFunction True)) bits)
    rightArrays = map (\(ind, value, _) -> (ind, value)) ((filter (filterFunction False)) bits)

-- ** Utils

-- | Binary search for abstract collection with get and compare operations
ultimateBinarySearch
  :: (Ord s, Num s, Integral s)
  => f                           -- ^ Collection
  -> (f -> s)                    -- ^ Get maximum selector
  -> (f -> s)                    -- ^ Get minimum selector
  -> (f -> s -> Maybe a)         -- ^ Get item
  -> (a -> Ordering)             -- ^ compare values, example (compare a)
  -> Maybe a
ultimateBinarySearch collection getMaxSelector getMinSelector getItem comp = recursion minSelector maxSelector
  where
    maxSelector = getMaxSelector collection
    minSelector = getMinSelector collection
    recursion left right
      | left > right = Nothing
      | left < minSelector || right > maxSelector = Nothing
      | otherwise = case ordering of
                    Just EQ -> value
                    Just LT -> recursion left (midPoint - 1)
                    Just GT -> recursion (midPoint + 1) right
                    Nothing -> Nothing
        where
          midPoint = fromInteger (ceiling ((fromIntegral (left + right)) / 2))
          value = collection `getItem` midPoint
          ordering = comp <$> value

