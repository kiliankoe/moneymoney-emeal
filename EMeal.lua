-- Reference: https://moneymoney-app.com/api/webbanking/

WebBanking{version     = 1.00,
           url         = 'https://kartenservice.studentenwerk-dresden.de',
           services    = {'Studentenwerk Dresden Emeal'},
           description = string.format(
               MM.localizeText("Get balance and transactions for %s"),
               "Studentenwerk Dresden Emeal"
           )}

function SupportsBank(protocol, bankCode)
    return protocol == ProtocolWebBanking and bankCode == 'Studentenwerk Dresden Emeal'
end

local swdUsername
local swdPassword
local authToken

local baseURL = 'https://kartenservicedaten.studentenwerk-dresden.de:8080/TL1/TLM/KASVC/'

function InitializeSession(protocol, bankCode, username, username2, password, username3)
    swdUsername = username
    swdPassword = password

    local url = baseURL .. 'LOGIN?datenformat=JSON&karteNr=' .. swdUsername
    local body = string.format('{"Passwort":"%s","BenutzerID":"%s"}', swdPassword, swdUsername)

    local json = post(url, body)
    authToken = json[1]['authToken']
    print('Acquired KartenService authToken')
end

function ListAccounts(knownAccounts)
    local account = {
        name = 'Emeal',
        owner = swdUsername,
        accountNumber = swdUsername,
        currency = 'EUR',
        type = AccountTypeOther
    }
    return {account}
end

function RefreshAccount(account, since)
    local dateStart = MM.localizeDate('dd.MM.yyyy', since)
    local dateEnd = MM.localizeDate('dd.MM.yyyy', os.time() + 24*3600)
    local urlStub = '?format=JSON&authToken=' .. authToken .. '&karteNr=' .. swdUsername .. '&datumVon=' .. dateStart .. '&datumBis=' .. dateEnd

    local posUrl = baseURL .. 'TRANSPOS' .. urlStub
    local posJson = get(posUrl)

    local transUrl = baseURL .. 'TRANS' .. urlStub
    local transJson = get(transUrl)

    local transactions = {}
    for _, rawTrans in pairs(transJson) do

        local positionsStr = ''
        for _, rawPos in pairs(posJson) do
            if rawPos['transFullId'] == rawTrans['transFullId'] then
                positionsStr = positionsStr .. ', ' .. rawPos['name']
            end
        end

        local timestamp = stringToTimestamp(rawTrans['datum'])

        local trans = {
            name = rawTrans['ortName'] .. ' ' .. rawTrans['kaName'],
            bookingDate = timestamp,
            purpose = rawTrans['typName'] .. positionsStr,
            amount = rawTrans['zahlBetrag'],
            bookingText = rawTrans['transFullId']
        }
        transactions[#transactions+1] = trans
    end

    return {
        balance = 0.0,
        transactions = transactions
    }
end

function EndSession() end

-- ---

local headers = {}
headers['Authorization'] = 'Basic S0FTVkM6ekt2NXlFMUxaVW12VzI5SQ==' -- this really is a static value... ¯\_(ツ)_/¯
headers['User-Agent'] = 'MoneyMoney Emeal Extension'

local connection = Connection()

function get(url)
    local content = connection:request('GET', url, nil, nil, headers)
    local json = JSON(content)
    return json:dictionary()
end

function post(url, body)
    local content = connection:request('POST', url, body, 'application/json', headers)
    local json = JSON(content)
    return json:dictionary()
end

function stringToTimestamp(str)
    -- 17.07.2018 13:37
    local datePattern = '(%d+).(%d+).(%d+) (%d+):(%d+)'
    local day, month, year, hour, min = str:match(datePattern)
    local timestamp = os.time({day=day,month=month,year=year,hour=hour,min=min})
    return timestamp
end
