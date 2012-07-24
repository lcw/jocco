import Text.Pandoc

main = toJsonFilter doiLinks

doiLinks :: Inline -> Inline
doiLinks (Str s)
  | (take 4 s) == "doi:" = RawInline "html" ("doi:<a href=\"http://dx.doi.org/" ++ (drop 4 s) ++ "\">" ++ (drop 4 s) ++ "</a>")
  | otherwise  = Str s
doiLinks x      = x
