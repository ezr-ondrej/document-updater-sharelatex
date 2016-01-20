sinon = require('sinon')
chai = require('chai')
should = chai.should()
zipModulePath = "../../../../app/js/ZipManager"
redisModulePath = "../../../../app/js/RedisManager"
SandboxedModule = require('sandboxed-module')
zlib = require('zlib')

MIN_SIZE = 9999

describe "ZipManager with RedisManager", ->
	describe "for a small document (uncompressed)", ->
		rclient = null
		beforeEach (done) ->
			@ZipManager = SandboxedModule.require zipModulePath,	requires:
				"logger-sharelatex": log:->
				'settings-sharelatex': redis:
					web:
						host: 'none'
						port: 'none'
					zip:
						writesEnabled: true
						minSize: MIN_SIZE
			@RedisManager = SandboxedModule.require redisModulePath,	requires:
				"./ZipManager" : @ZipManager
				"redis-sharelatex" : createClient: () =>
					rclient ?=
						auth:-> # only assign one rclient
						multi: () => rclient
						set: (key, value) => rclient.store[key] = value
						get: (key) =>	rclient.results.push rclient.store[key]
						incr: (key) => rclient.store[key]++
						exec: (callback) =>
							callback.apply(null, [null, rclient.results])
							rclient.results = []
						store: {}
						results: []
				"logger-sharelatex": {}
			@doc_id = "document-id"
			@version = 123

			@docLines = ["hello", "world"]
			@callback = sinon.stub()

			@RedisManager.setDocument @doc_id, @docLines, @version, () =>
				@callback()
				done()

		it "should set the document", ->
			rclient.store['doclines:document-id']
				.should.equal JSON.stringify(@docLines)

		it "should return the callback", ->
			@callback.called.should.equal true

		it "should get the document back again", (done) ->
			@RedisManager.getDoc @doc_id, (err, lines, version) =>
				@docLines.should.eql lines
				done()

	describe "calling node zlib.gzip directly", ->
		it "should compress the string 'hello world' within the timeout", (done) ->
			zlib.gzip "hello world", done

		it "should compress a 10k string within the timeout", (done) ->
			text = ""
			while text.length < 10*1024
				text = text + "helloworld"
			zlib.gzip text, done

	describe "for a large document (with compression enabled)", ->
		rclient = null
		beforeEach (done) ->
			@ZipManager = SandboxedModule.require zipModulePath,	requires:
				"logger-sharelatex": log:->
				'settings-sharelatex': redis:
					web:
						host: 'none'
						port: 'none'
					zip:
						writesEnabled: true
						minSize: MIN_SIZE
			@RedisManager = SandboxedModule.require redisModulePath,	requires:
				"./ZipManager" : @ZipManager
				"redis-sharelatex" : createClient: () =>
					rclient ?=
						auth:-> # only assign one rclient
						multi: () => rclient
						set: (key, value) => rclient.store[key] = value
						get: (key) => rclient.results.push rclient.store[key]
						incr: (key) => rclient.store[key]++
						exec: (callback) =>
							callback.apply(null, [null, rclient.results])
							rclient.results = []
						store: {}
						results: []
				"logger-sharelatex": {}
			@doc_id = "document-id"
			@version = 123

			@docLines = []
			while @docLines.join('').length <= MIN_SIZE
				@docLines.push "this is a long line in a long document"
			# console.log "length of doclines", @docLines.join('').length
			@callback = sinon.stub()
			@RedisManager.setDocument @doc_id, @docLines, @version, () =>
				@callback()
				done()

		it "should set the document as a gzipped blob", ->
			rclient.store['doclines:document-id']
				.should.not.equal JSON.stringify(@docLines)

		it "should return the callback", ->
			@callback.called.should.equal true

		it "should get the uncompressed document back again", (done) ->
			@RedisManager.getDoc @doc_id, (err, lines, version) =>
				@docLines.should.eql lines
				done()

	describe "for a large document (with compression disabled)", ->
		rclient = null
		beforeEach (done) ->
			@ZipManager = SandboxedModule.require zipModulePath,	requires:
				"logger-sharelatex": log:->
				'settings-sharelatex': redis:
					web:
						host: 'none'
						port: 'none'
					zip:
						writesEnabled: false
						minSize: MIN_SIZE
			@RedisManager = SandboxedModule.require redisModulePath,	requires:
				"./ZipManager" : @ZipManager
				"redis-sharelatex" : createClient: () =>
					rclient ?=
						auth:-> # only assign one rclient
						multi: () => rclient
						set: (key, value) => rclient.store[key] = value
						get: (key) => rclient.results.push rclient.store[key]
						incr: (key) => rclient.store[key]++
						exec: (callback) =>
							callback.apply(null, [null, rclient.results])
							rclient.results = []
						store: {}
						results: []
				"logger-sharelatex": {}
			@doc_id = "document-id"
			@version = 123
			@docLines = []
			while @docLines.join('').length <= MIN_SIZE
				@docLines.push "this is a long line in a long document"
			@callback = sinon.stub()
			@RedisManager.setDocument @doc_id, @docLines, @version, () =>
				@callback()
				done()

		it "should set the document", ->
			rclient.store['doclines:document-id']
				.should.equal JSON.stringify(@docLines)

		it "should return the callback", ->
			@callback.called.should.equal true

		it "should get the document back again", (done) ->
			@RedisManager.getDoc @doc_id, (err, lines, version) =>
				@docLines.should.eql lines
				done()
