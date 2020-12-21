# Regular Expressions
# by Benjamin Lee
# Version 2.0.0
# Last updated Dec 20 12020


type Char = String # No functionality impact; read as 'one-character string' (e.g. "a", "", etc)

data RE<T>:
    # Based on Olin Shivers' SRE notation [1], modified.
    
    # "T" and "term" refer to terms of an expression (of a regular language) — this usually means
    # unicode characters, but they could also be entire strings, numbers, or any other type for 
    # which equality is well-defined. 
    
    # Single-term matchers
  | re-any                           # Matches any term
  | re-char-seq(seq :: List<T>)      # Matches the exact sequence of term
  | re-char-set(chars :: Set<T>)     # Matches any term in the set
  | re-char-set-not(chars :: Set<T>) # Matches any term not in the set
    
    # Regular expression concatenation & alternation
  | re-seq(seq :: List<RE<T>>)   # Matches the REs in sequence
  | re-or(choices :: Set<RE<T>>) # Matches any of the REs in the set
    
    # Repetition
  | re-zero-or-more(re :: RE<T>)                     # * operator (Kleene star)
  | re-one-or-more(re :: RE<T>)                      # + operator (Kleene plus)
  | re-zero-or-one(re :: RE<T>)                      # ? operator
  | re-n-exactly(n :: Number, re :: RE<T>)           # Matches re n times
  | re-n-or-more(n :: Number, re :: RE<T>)           # Matches re n or more times
  | re-n-to-m(n :: Number, m :: Number, re :: RE<T>) # Matches re n to m times, inclusive
        
    # Submatches
  | re-submatch(re :: RE<T>) # Records the submatch matching re
  | re-dsm(n-before :: Number, n-after :: Number, re :: RE<T>) 
    # Preserves submatch indices through optimizations that might delete re-submatches
    
    # Anchors
  | re-start # Matches at beginning
  | re-end   # Matches at end
    
    # String-specific:
  | re-bol # Matches at beginning of string or after a newline ("\n")
  | re-eol # Matches at end of string or before a newline
  | re-bow # Matches at the start of a "word" (sequence of alphanum/underscore chars)
  | re-eow # Matches at the end of a "word"
  | re-case-insensitive(re :: RE<Char>) # Matches the re with/without regard for capitalization,
  | re-case-sensitive(re :: RE<Char>)   # as defined by string-to-upper.
  | re-range-string(s :: String) # Forms a range from pairs by code point: "azMZ" is abc…xyzMNO…XYZ
  | re-posix-string(s :: String) # Matches any string matching the given POSIX regexp string
end


fun range-str-to-set(s :: String) -> Set<Char>:
  doc: ```Takes characters in pairs to form ranges by code point.
       Only accepts characters with code points that are less than 65536.
       ```
  l :: List<Char> = string-explode(s)
  range-char-list-to-set(l)
where:
  range-str-to-set("") is [tree-set: ]
  
  range-str-to-set("aa") is [tree-set: "a"]

  range-str-to-set("ab") is [tree-set: "a", "b"]

  range-str-to-set("az") is [tree-set: 
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", 
    "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", 
    "u", "v", "w", "x", "y", "z"]
  
  range-str-to-set("azA") is [tree-set: 
    "A", "a", "b", "c", "d", "e", "f", "g", "h", "i",
    "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", 
    "t", "u", "v", "w", "x", "y", "z"]
  
  range-str-to-set("azAZ") is [tree-set: 
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", 
    "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", 
    "U", "V", "W", "X", "Y", "Z", "a", "b", "c", "d", 
    "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", 
    "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", 
    "y", "z"]
  
  range-str-to-set("aZ") is [tree-set: 
    "Z", "[", "\\", "]", "^", "_", "`", "a"]
  # Remember that ranges are by code point!
end

fun range-char-list-to-set(l :: List<Char>) -> Set<Char>:
  doc: ```Takes characters in pairs to form ranges by code point.
       Only accepts characters with code points that are less than 65536.
       ```
  cases (List<Char>) l:
    | empty => [tree-set: ]
    | link(first :: Char, next) =>
      cases (List<Char>) next:
        | empty => [tree-set: first]
        | link(second :: Char, rest) =>
          first-point  = string-to-code-point(first)
          second-point = string-to-code-point(second)
          
          point-subrange = 
            if first-point <= second-point: range(first-point, second-point + 1) 
            else: range(second-point, first-point + 1) end
          # Range is inclusive.
          
          subrange-char-list = map(string-from-code-point, point-subrange)
          subrange-char-set  = list-to-tree-set(subrange-char-list)
            
          range-char-list-to-set(rest).union(subrange-char-set)
      end
  end
where:
  range-char-list-to-set([list: ]) is [tree-set: ]
  
  range-char-list-to-set([list: "a", "a"]) is [tree-set: "a"]

  range-char-list-to-set([list: "a", "b"]) is [tree-set: "a", "b"]

  range-char-list-to-set([list: "a", "z"]) is [tree-set: 
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", 
    "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", 
    "u", "v", "w", "x", "y", "z"]
  
  range-char-list-to-set([list: "a", "z", "A"]) is [tree-set: 
    "A", "a", "b", "c", "d", "e", "f", "g", "h", "i", 
    "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", 
    "t", "u", "v", "w", "x", "y", "z"]
  
  range-char-list-to-set([list: "a", "z", "A", "Z"]) is [tree-set: 
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", 
    "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", 
    "U", "V", "W", "X", "Y", "Z", "a", "b", "c", "d", 
    "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", 
    "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", 
    "y", "z"]
  
  range-char-list-to-set([list: "a", "Z"]) is [tree-set: 
    "Z", "[", "\\", "]", "^", "_", "`", "a"]
  # Remember that ranges are by code point!
end


# ==============================================================================
# References
# ------------------------------------------------------------------------------
#| 
   [1] Olin Shivers, "The SRE regular-expression notation," August, 1998. 
       [Online]. Avaliable: www.ccs.neu.edu/home/shivers/papers/sre.txt 
       (web.archive.org/web/20191228112153/http://www.ccs.neu.edu/home/shivers/
       papers/sre.txt). [Accessed Dec. 20, 2020].

|#