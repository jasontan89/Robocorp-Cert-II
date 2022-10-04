*** Settings ***
Documentation       Orders robots from RobotSpareBin Industries Inc.
...                 Saves the order HTML receipt as a PDF file.
...                 Saves the screenshot of the ordered robot.
...                 Embeds the screenshot of the robot to the PDF receipt.
...                 Creates ZIP archive of the receipts and the images.

Library             RPA.Browser.Selenium    auto_close=${FALSE}
Library             RPA.HTTP
Library             RPA.Excel.Files
Library             RPA.Tables
Library             RPA.PDF
Library             RPA.Archive
Library             RPA.FileSystem
Library             RPA.Robocorp.Vault
Library             RPA.Dialogs
Library             RPA.Notifier


*** Variables ***
#${EXCEL_FILE_PATH}=    ${CURDIR}${/}devdata${/}Data.xlsx
${PDF_TEMP_OUTPUT_DIRECTORY}=       ${CURDIR}${/}temp
#${PDF_TEMPLATE_PATH}=    ${CURDIR}${/}devdata${/}invite.template


*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    ${secret}=    Get credential from Vault
    ${user_url}=    Input form dialog
    Check Link    ${user_url}    ${secret}[url]
    Set up directories
    Open Browser to Robot ordering Page    ${secret}[url]
    Download the CSV file
    Fill the form using the data from the Excel file
    Create ZIP package from PDF files
    # Input form dialog    ${secret}    #Ask user to send email to production on new orders. Removed due to password


*** Keywords ***
Get credential from Vault
    ${secret}=    Get Secret    secret
    RETURN    ${secret}

Input form dialog
    Add heading    Send feedback
    Add text    Please paste the robot ordering link to authenticate
    Add text input    link    label=URL Link
    ${result}=    Run dialog
    RETURN    ${result.link}

Check Link
    [Arguments]    ${user_url}    ${secret}
    WHILE    True
        IF    "${secret}" == "${user_url}"
            Success dialog
            BREAK
        ELSE
            ${user_url}=    Input form dialog
        END
    END

Open Browser to Robot ordering Page
    [Arguments]    ${url}
    Open Available Browser    ${url}
    Wait Until Page Contains Element    css:div[class="modal-dialog"]
    Click Button    css:button[class="btn btn-dark"]

Set up directories
    Create Directory    ${PDF_TEMP_OUTPUT_DIRECTORY}
    Create Directory    ${OUTPUT_DIR}

Input order into ordering field
    [Arguments]    ${robot}
    #${string}    Set Variable    Element 'id:order-another' did not appear in 5 seconds.
    Select From List By Value    id:head    ${robot}[Head]
    Select Radio Button    body    ${robot}[Body]
    Input Text    xpath:/html/body/div/div/div[1]/div/div[1]/form/div[3]/input    ${robot}[Legs]
    Input Text    id:address    ${robot}[Address]
    Click Button    id:preview
    Wait Until Element Is Visible    id:robot-preview-image
    Screenshot    id:robot-preview-image    ${OUTPUT_DIR}${/}${robot}[Order number].png
    Click Button    id:order    #potential server timeout, need to press order again
    TRY
        Wait Until Page Contains Element    id:order-another    #wait for order another button to appear
    EXCEPT    Element 'id:order-another' did not appear in 5 seconds.
        Wait Until Keyword Succeeds    4x    1s    Retry ordering
        #Click Button    id:order-another    #click on order another robot button
    END
    Save html to pdf    ${robot}[Order number]
    Embed screenshot to pdf    ${robot}[Order number]
    Click Button    id:order-another    #click on order another robot button
    Handle pesky dialog

 Download the CSV file
    Download    https://robotsparebinindustries.com/orders.csv    overwrite=True

Save html to pdf
    [Arguments]    ${row}
    Wait Until Element Is Visible    id:receipt
    ${sales_results_html}=    Get Element Attribute    id:receipt    outerHTML
    Html To Pdf    ${sales_results_html}    ${OUTPUT_DIR}${/}receipt${row}.pdf

Embed screenshot to pdf
    [Arguments]    ${row}
    Wait Until Element Is Visible    id:receipt
    ${sales_results_html}=    Get Element Attribute    id:receipt    outerHTML

    ${files}=    Create List
    ...    ${OUTPUT_DIR}${/}receipt${row}.pdf
    ...    ${OUTPUT_DIR}${/}${row}.png
    Add Files To Pdf    ${files}    ${PDF_TEMP_OUTPUT_DIRECTORY}${/}added_receipt${row}.pdf

Fill the form using the data from the Excel file
    ${robot_order}=    Read table from CSV    orders.csv
    FOR    ${robot}    IN    @{robot_order}
        Input order into ordering field    ${robot}
    END

Create ZIP package from PDF files
    ${zip_file_name}=    Set Variable    ${OUTPUT_DIR}/PDFs.zip
    Archive Folder With Zip
    ...    ${PDF_TEMP_OUTPUT_DIRECTORY}
    ...    ${zip_file_name}

Handle pesky dialog
    Wait Until Page Contains Element    css:div[class="modal-dialog"]    #wait for pesky dialog to confirm
    Click Button    css:button[class="btn btn-dark"]    #press ok

Retry ordering
    Click Button    id:order    #potential server timeout, need to press order again
    Wait Until Page Contains Element    id:order-another

Fill and submit the form for one person
    [Arguments]    ${robot}
    Input Text    firstname    ${robot}[First Name]
    Input Text    lastname    ${robot}[Last Name]
    Input Text    salesresult    ${robot}[Sales]
    Select From List By Value    salestarget    ${robot}[Sales Target]
    Click Button    Submit

Try Again
    Click Button    id:order
    Wait Until Page Contains Element    id:order-another

Success dialog
    Add icon    Success
    Add heading    Your Link is correct, proceeding with ordering process
    Run dialog    title=Success

Failure dialog    #not implemented, too irritating due to pre empt failure
    Add icon    Failure
    Add heading    There was an error in purchasing, please hold on
    Add text    The assistant failed to complete the ordering process
    Add link    https://robocorp.com/docs    label=Troubleshooting guide
    Run dialog    title=Warning System Error

# Input form dialog
#    [Arguments]    ${secret}
#    Add heading    Send feedback
#    Add text input    email    label=E-mail address
#    Add text input    message
#    ...    label=Feedback
#    ...    placeholder=Enter feedback here
#    ...    rows=5
#    ${result}=    Run dialog
#    Notify user    ${result.email}    ${result.message}    ${secret}

# Notify user
#    [Arguments]    ${result.email}    ${result.message}    ${secret}
#    Notify Gmail
#    ...    message=${result.message}
#    ...    to=${result.email}
#    ...    username=${secret}[username]
#    ...    password=${secret}[password]
#    ...    subject=New orders incoming, please check your cloud server
