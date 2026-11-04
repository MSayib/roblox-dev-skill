-- expect: a passing preferred colour is kept, a failing one falls back to black or white, as the docs show.
local white, black = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local brand = Color3.fromRGB(255, 165, 0)
-- The luau-lsp definitions do not list these methods yet (run_static: defs-behind).
local blackAny: any, whiteAny: any, brandAny: any = black, white, brand
__skilltest.eq("orange falls back to black on white", readableTextColor(white, brand), black)
__skilltest.eq("orange is kept on black", readableTextColor(black, brand), brand)
__skilltest.eq("no preference on dark blue is white", readableTextColor(Color3.fromRGB(0, 0, 139)), white)
__skilltest.eq("no preference on orange is black", readableTextColor(brand), black)
__skilltest.check("black against white is about 21", math.abs(blackAny:GetContrastRatio(white) - 21) < 0.001)
__skilltest.eq("ratio is symmetric", blackAny:GetContrastRatio(white), whiteAny:GetContrastRatio(black))
__skilltest.check("red luminance is about 0.2126", math.abs((Color3.fromRGB(255, 0, 0) :: any):GetLuminance() - 0.2126) < 0.0001)
local offBlack, offWhite = Color3.fromRGB(20, 20, 20), Color3.fromRGB(240, 240, 240)
__skilltest.eq("custom candidates", brandAny:GetContrastingColor(offBlack, offWhite), offBlack)
