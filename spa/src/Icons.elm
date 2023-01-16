module Icons exposing (download, downloadOff, folder, icon, upload, uploadOff)

import Html as H
import Html.Attributes as A


icon : String -> H.Html msg
icon name =
    H.span [ A.class "material-symbols-outlined" ] [ H.text name ]



-- INDIVIDUAL ICONS


folder : H.Html msg
folder =
    icon "folder"


download : H.Html msg
download =
    icon "download"


downloadOff : H.Html msg
downloadOff =
    icon "file_download_off"


upload : H.Html msg
upload =
    icon "upload"


uploadOff : H.Html msg
uploadOff =
    icon "file_upload_off"
